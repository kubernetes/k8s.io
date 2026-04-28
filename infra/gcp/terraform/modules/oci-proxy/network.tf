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

locals {
  // like var.domain, but usable in name keys
  domain_id = replace("${var.domain}", ".", "-")
}

# This challenge must be created first, then the DNS challenge must be added
# To our DNS config under dns/
#
# Bootstrapping this for use with Certificate Manager will allow us to decouple
# cert provisioning from LBs, to have a valid cert pre-provisioned before
# we point traffic at an LB
resource "google_certificate_manager_dns_authorization" "default" {
  name        = "${local.domain_id}-dnsauth"
  description = "The default dns auth"
  domain      = var.domain
  project     = var.project_id
}

# Using the challenge, provision a cert for the domain
resource "google_certificate_manager_certificate" "default" {
  name    = "${local.domain_id}-20230508"
  project = var.project_id
  managed {
    domains            = [var.domain]
    dns_authorizations = [google_certificate_manager_dns_authorization.default.id]
  }
}

# Map certificate to domain for use with GCLB
resource "google_certificate_manager_certificate_map" "default" {
  project = var.project_id
  name    = local.domain_id
}
resource "google_certificate_manager_certificate_map_entry" "default" {
  project      = var.project_id
  name         = "${local.domain_id}-default"
  map          = google_certificate_manager_certificate_map.default.name
  certificates = [google_certificate_manager_certificate.default.id]
  matcher      = "PRIMARY"
}

# IP Addresses for the loadbalancer
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

  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default.id}"
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

  enable_cdn      = false
  security_policy = google_compute_security_policy.cloud-armor.self_link

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
