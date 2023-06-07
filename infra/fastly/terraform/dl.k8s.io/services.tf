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

locals {
  domain_name = "cdn.dl.k8s.io"
}

resource "fastly_service_vcl" "files" {
  name     = local.domain_name
  activate = true

  domain {
    name = local.domain_name
  }

  backend {
    name             = "GCS"
    auto_loadbalance = false

    healthcheck = "GCS Health"

    address           = "storage.googleapis.com"
    port              = 443
    use_ssl           = true
    ssl_cert_hostname = "storage.googleapis.com"
    ssl_sni_hostname  = "storage.googleapis.com"

    override_host = "${var.bucket}.storage.googleapis.com"

    connect_timeout       = 5000  # milliseconds
    first_byte_timeout    = 60000 # milliseconds
    between_bytes_timeout = 15000 # milliseconds
    error_threshold       = 5
  }

  healthcheck {
    name = "GCS Health"

    host           = "${var.bucket}.storage.googleapis.com"
    method         = "GET"
    path           = "/"
    check_interval = 3000
    timeout        = 2000
    threshold      = 2
    initial        = 2
    window         = 4
  }

  snippet {
    content  = <<-EOT
      if (req.url.path ~ "^/release/") {
        set req.enable_segmented_caching = true;
      }
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

  # Remove Google cookies from the origin
  header {
    destination = "http.x-goog-generation"
    type        = "cache"
    action      = "delete"
    name        = "remove x-goog-generation"
  }

  header {
    destination = "http.x-goog-metageneration"
    type        = "cache"
    action      = "delete"
    name        = "remove x-goog-metageneration"
  }

  header {
    destination = "http.x-guploader-uploadid"
    type        = "cache"
    action      = "delete"
    name        = "remove x-guploader-uploadid"
  }

  header {
    destination = "http.x-goog-hash"
    type        = "cache"
    action      = "delete"
    name        = "remove x-goog-hash"
  }

  header {
    destination = "http.x-goog-meta-goog-reserved-file-mtime"
    type        = "cache"
    action      = "delete"
    name        = "remove x-goog-meta-goog-reserved-file-mtime"
  }

  header {
    destination = "http.x-goog-storage-class"
    type        = "cache"
    action      = "delete"
    name        = "remove x-goog-storage-class"
  }

  header {
    destination = "http.x-goog-stored-content-encoding"
    type        = "cache"
    action      = "delete"
    name        = "remove x-goog-stored-content-encoding"
  }

  header {
    destination = "http.x-goog-stored-content-length"
    type        = "cache"
    action      = "delete"
    name        = "remove x-goog-stored-content-length"
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

  vcl {
    name    = "Main"
    content = file("${path.module}/vcl/binaries.vcl")
    main    = true
  }

  force_destroy = true
}

resource "fastly_tls_subscription" "files" {
  domains               = [for domain in fastly_service_vcl.files.domain : domain.name]
  certificate_authority = "lets-encrypt"
}

output "files_managed_dns_challenge" {
  value = fastly_tls_subscription.files.managed_dns_challenges
}
