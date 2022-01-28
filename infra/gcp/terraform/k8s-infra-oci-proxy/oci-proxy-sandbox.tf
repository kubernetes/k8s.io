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
  project_id = "k8s-infra-oci-proxy"
  domain     = "proxy.k8s.io"
  image      = "gcr.io/k8s-infra-staging-infra-tools/oci-proxy"

  external_ips = {
    sandbox = {
      name = "${local.project_id}-sandbox",
    },
    sandbox-v6 = {
      name = "${local.project_id}-sandbox-v6",
      ipv6 = true
    },
  }
}

data "google_billing_account" "account" {
  billing_account = "018801-93540E-22A20E"
}

data "google_organization" "org" {
  domain = "kubernetes.io"
}

resource "google_project" "project" {
  name            = local.project_id
  project_id      = local.project_id
  org_id          = data.google_organization.org.org_id
  billing_account = data.google_billing_account.account.id
}


// Enable services needed for the project
resource "google_project_service" "project" {
  project = google_project.project.id

  for_each = toset([
    "compute.googleapis.com",
    "containerregistry.googleapis.com",
    "logging.googleapis.com",
    "oslogin.googleapis.com",
    "pubsub.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com"
  ])

  service = each.key
}

// Ensure IPv4 et IPv6 global addresses for oci-proxy
resource "google_compute_global_address" "global_ips" {
  project      = google_project.project.project_id
  for_each     = local.external_ips
  name         = each.value.name
  description  = lookup(each.value, "description", null)
  address_type = "EXTERNAL"
  ip_version   = lookup(each.value, "ipv6", false) ? "IPV6" : "IPV4"
}
