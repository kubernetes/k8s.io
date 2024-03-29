/*
Copyright 2022 The Kubernetes Authors.

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

resource "google_compute_global_address" "default_ipv4" {
  project      = google_project.project.project_id
  name         = "k8s-infra-porche-v4"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_global_address" "default_ipv6" {
  project      = google_project.project.project_id
  name         = "k8s-infra-porche-v6"
  address_type = "EXTERNAL"
  ip_version   = "IPV6"
}

data "google_compute_global_address" "default_ipv4" {
  project = google_project.project.project_id
  name    = "k8s-infra-porche-v4"
}

data "google_compute_global_address" "default_ipv6" {
  project = google_project.project.project_id
  name    = "k8s-infra-porche-v6"
}

resource "google_compute_region_network_endpoint_group" "default" {
  for_each = google_cloud_run_service.regions

  provider              = google-beta
  project               = google_project.project.project_id
  name                  = "${var.project_id}--${each.key}--neg"
  network_endpoint_type = "SERVERLESS"
  region                = google_cloud_run_service.regions[each.key].location
  cloud_run {
    service = google_cloud_run_service.regions[each.key].name
  }
}


# IPv4 and IPv6 forwarding rules (listeners)
resource "google_compute_global_forwarding_rule" "http_ipv4" {
  project    = google_project.project.project_id
  name       = "artifacts-k8s-io-ipv4-http"
  target     = google_compute_target_http_proxy.default.self_link
  ip_address = google_compute_global_address.default_ipv4.address
  port_range = "80"
}

resource "google_compute_global_forwarding_rule" "https_ipv4" {
  project    = google_project.project.project_id
  name       = "artifacts-k8s-io-ipv4-https"
  target     = google_compute_target_https_proxy.default.self_link
  ip_address = google_compute_global_address.default_ipv4.address
  port_range = "443"
}


resource "google_compute_global_forwarding_rule" "http_ipv6" {
  project    = google_project.project.project_id
  name       = "artifacts-k8s-io-ipv6-http"
  target     = google_compute_target_http_proxy.default.self_link
  ip_address = google_compute_global_address.default_ipv6.address
  port_range = "80"
}

resource "google_compute_global_forwarding_rule" "https_ipv6" {
  project    = google_project.project.project_id
  name       = "artifacts-k8s-io-ipv6-https"
  target     = google_compute_target_https_proxy.default.self_link
  ip_address = google_compute_global_address.default_ipv6.address
  port_range = "443"
}

# Redirect HTTP to HTTPS
resource "google_compute_target_http_proxy" "default" {
  project = google_project.project.project_id
  name    = "artifacts-k8s-io-default"
  url_map = google_compute_url_map.https_redirect.self_link
}

resource "google_compute_url_map" "https_redirect" {
  project = google_project.project.project_id
  name    = "artifacts-k8s-io-https-redirect"
  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}


# Serve HTTPS
resource "google_compute_target_https_proxy" "default" {
  project = google_project.project.project_id
  name    = "artifacts-k8s-io-https-proxy"
  url_map = google_compute_url_map.default.self_link

  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.artifacts-k8s-io.id}"
}

resource "google_compute_url_map" "default" {
  project         = google_project.project.project_id
  name            = "artifacts-k8s-io-url-map"
  default_service = google_compute_backend_service.default.self_link
}

resource "google_compute_backend_service" "default" {
  project = google_project.project.project_id
  name    = "artifacts-k8s-io-backend-default"

  enable_cdn = false

  dynamic "backend" {
    for_each = google_compute_region_network_endpoint_group.default
    content {
      group = backend.value.id
    }
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}


/*

module "lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 7.0.0"

  project = google_project.project.project_id
  name    = var.project_id

  # ...
  backends = {
    default = {
      description = null
      groups = [
        for neg in google_compute_region_network_endpoint_group.default :
        {
          group = neg.id
        }
      ]
      enable_cdn              = false
      security_policy         = null
      custom_request_headers  = null
      custom_response_headers = null
      compression_mode = null
      protocol = null
      port_name = null

      iap_config = {
        enable               = false
        oauth2_client_id     = ""
        oauth2_client_secret = ""
      }

      log_config = {
        enable      = true
        sample_rate = "1.0"
      }
    }
  }
  create_address      = false
  create_ipv6_address = false
  enable_ipv6         = true
  https_redirect      = true
  #TODO(ameukam): current the TF resource google_compute_global_address don't have
  #the value of IP in his attribute. But it's accessible with the data source:
  #https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_global_address
  address      = data.google_compute_global_address.default_ipv4.address
  ipv6_address = data.google_compute_global_address.default_ipv6.address
  ssl                       = true
  use_ssl_certificates      = true
  #ssl_certificates = [
  #  google_certificate_manager_certificate.artifacts-k8s-io.id,
  #]
  certificate_map = google_certificate_manager_certificate_map.artifacts-k8s-io.id
}

*/