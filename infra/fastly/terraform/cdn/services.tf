/*
Copyright 2023 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/


resource "fastly_service_vcl" "this" {
  name     = var.domain
  activate = true

  domain {
    name = var.domain
  }

  dynamic "backend" {
    for_each = var.bucket_configs
    content {
      name              = backend.value.release_bucket ? "k8s-release" : backend.value.name
      auto_loadbalance  = false
      address           = "storage.googleapis.com"
      port              = 443
      use_ssl           = true
      prefer_ipv6       = true
      ssl_cert_hostname = "storage.googleapis.com"
      ssl_sni_hostname  = "storage.googleapis.com"

      override_host = "${backend.value.name}.storage.googleapis.com"

      /*
      Matching the region of the origin.
      Full list: https://www.fastly.com/documentation/guides/concepts/shielding/#choosing-a-shield-location
      */
      shield = var.shield_location

      connect_timeout       = 5000  # milliseconds
      between_bytes_timeout = 15000 # milliseconds
      error_threshold       = 5
    }
  }

  logging_datadog {
    name   = "dd-oss-k8s"
    token  = var.datadog_config["token"]
    region = "US5"
    format = templatefile("${path.module}/fastly-log-format.tftpl", {
      service_name = var.datadog_config["service_name"],
      dd_app       = "releases",
      dd_env       = var.datadog_config["env"],
    })
  }

  snippet {
    content  = <<-EOT
      set req.enable_segmented_caching = true;
    EOT
    name     = "Enable segment caching for large files"
    priority = 60
    type     = "recv"
  }

  # Allow CORS GET requests.
  header {
    destination = "http.access-control-allow-origin"
    type        = "response"
    action      = "set"
    name        = "CORS Allow"
    source      = "\"*\""
  }

  # Do not cache 'not found' & authenticated requests:
  condition {
    type      = "CACHE"
    name      = "is-not-found"
    statement = "beresp.status == 404"
  }

  cache_setting {
    name            = "pass-not-found"
    cache_condition = "is-not-found"
    action          = "pass"
    ttl             = 120
    stale_ttl       = 120
  }

  request_setting {
    name      = "Force TLS"
    force_ssl = true
    xff       = "leave"
  }

  snippet {
    name = "Authenticate to GCS requests"
    type = "init"
    content = templatefile("${path.module}/vcl/gcs-auth-multi.vcl", {
      bucket_configs = var.bucket_configs
      access_key     = var.gcs_access_key
      secret_key     = var.gcs_secret_key
    })
  }

  vcl {
    name    = "Main"
    content = file("${path.module}/vcl/binaries.vcl")
    main    = true
  }

  product_enablement {
    ddos_protection {
      enabled = true
      mode    = "log"
    }
    log_explorer_insights = true
    origin_inspector      = true
    domain_inspector      = true
  }

  http3         = true
  force_destroy = true
}

# resource "fastly_tls_subscription" "this" {
#   domains               = [var.domain]
#   common_name           = var.domain
#   certificate_authority = "lets-encrypt"
# }
