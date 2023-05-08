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

###############################################################################
# v2 loadbalancer with EXTERNAL_MANAGED mode
# this will eventually replace the lb-http setup below

resource "google_compute_global_address" "ipv4" {
  project      = var.project_id
  name         = "${var.project_id}-ipv4"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_global_address" "ipv6" {
  project      = var.project_id
  name         = "${var.project_id}-ipv6"
  address_type = "EXTERNAL"
  ip_version   = "IPV6"
}


# IPv4 and IPv6 forwarding rules (listeners)
resource "google_compute_global_forwarding_rule" "http_ipv4" {
  project               = var.project_id
  name                  = "${var.project_id}-ipv4-http-managed"
  target                = google_compute_target_http_proxy.default.self_link
  ip_address            = google_compute_global_address.ipv4.address
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_compute_global_forwarding_rule" "https_ipv4" {
  project               = var.project_id
  name                  = "${var.project_id}-ipv4-https-managed"
  target                = google_compute_target_https_proxy.default.self_link
  ip_address            = google_compute_global_address.ipv4.address
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_compute_global_forwarding_rule" "http_ipv6" {
  project               = var.project_id
  name                  = "${var.project_id}-ipv6-http-managed"
  target                = google_compute_target_http_proxy.default.self_link
  ip_address            = google_compute_global_address.ipv6.address
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_compute_global_forwarding_rule" "https_ipv6" {
  project               = var.project_id
  name                  = "${var.project_id}-ipv6-https-managed"
  target                = google_compute_target_https_proxy.default.self_link
  ip_address            = google_compute_global_address.ipv6.address
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Redirect HTTP to HTTPS
resource "google_compute_target_http_proxy" "default" {
  project = var.project_id
  name    = "${var.project_id}-http-default"
  url_map = google_compute_url_map.https_redirect.self_link
}

resource "google_compute_url_map" "https_redirect" {
  project = var.project_id
  name    = "${var.project_id}-http-to-https-redirect"
  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# Serve HTTPS
resource "google_compute_target_https_proxy" "default" {
  project = var.project_id
  name    = "${var.project_id}-default-https-proxy"
  url_map = google_compute_url_map.default.self_link

  # TODO: pivot to managing cert outside of lb-http module
  ssl_certificates = var.ssl_certificates
}

resource "google_compute_region_network_endpoint_group" "default" {
  for_each = google_cloud_run_service.oci-proxy

  provider              = google-beta
  project               = var.project_id
  name                  = "${var.project_id}-${each.key}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = google_cloud_run_service.oci-proxy[each.key].location
  cloud_run {
    service = google_cloud_run_service.oci-proxy[each.key].name
  }
}


resource "google_compute_url_map" "default" {
  project         = var.project_id
  name            = "${var.project_id}-default-url-map"
  default_service = google_compute_backend_service.default.self_link
}

resource "google_compute_backend_service" "default" {
  project = var.project_id
  name    = "${var.project_id}-default-bes"

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

  load_balancing_scheme = "EXTERNAL_MANAGED"
}



################################################################################
# old resources for use with lb-http


resource "google_compute_global_address" "default_ipv4" {
  project      = var.project_id
  name         = var.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  depends_on = [
    google_project_service.project["compute.googleapis.com"],
  ]
}

resource "google_compute_global_address" "default_ipv6" {
  project      = var.project_id
  name         = "${var.project_id}-v6"
  address_type = "EXTERNAL"
  ip_version   = "IPV6"

  depends_on = [
    google_project_service.project["compute.googleapis.com"],
  ]
}

data "google_compute_global_address" "default_ipv4" {
  project = var.project_id
  name    = var.project_id
}

data "google_compute_global_address" "default_ipv6" {
  project = var.project_id
  name    = "${var.project_id}-v6"
}

resource "google_compute_region_network_endpoint_group" "oci-proxy" {
  for_each = google_cloud_run_service.oci-proxy

  provider              = google-beta
  project               = var.project_id
  name                  = "${var.project_id}--${each.key}--neg"
  network_endpoint_type = "SERVERLESS"
  region                = google_cloud_run_service.oci-proxy[each.key].location
  cloud_run {
    service = google_cloud_run_service.oci-proxy[each.key].name
  }
}

module "lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 6.2.0"

  project = var.project_id
  name    = var.project_id

  # ...
  backends = {
    default = {
      description = null
      groups = [
        for neg in google_compute_region_network_endpoint_group.oci-proxy :
        {
          group = neg.id
        }
      ]
      enable_cdn              = false
      security_policy         = null
      custom_request_headers  = null
      custom_response_headers = null

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
  managed_ssl_certificate_domains = [
    var.domain
  ]
  random_certificate_suffix = true
  ssl                       = true
  use_ssl_certificates      = false
  security_policy           = google_compute_security_policy.cloud-armor.self_link
}
