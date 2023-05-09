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

# Resources for new envoy-based loadbalancer / EXTERNAL_MANAGED mode.
################################################################################

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


# old resources for use with lb-http
################################################################################

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
