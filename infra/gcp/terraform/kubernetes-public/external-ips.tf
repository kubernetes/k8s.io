/*
This file defines all the external IP addresses in kubernetes-public
*/

// used by gcsweb.k8s.io
resource "google_compute_global_address" "gcsweb_k8s_io" {
  project      = data.google_project.project.project_id
  name         = "gcsweb-k8s-io"
  address_type = "EXTERNAL"
}

// used by canary.k8s.io
resource "google_compute_global_address" "k8s_io_ingress_canary" {
  project      = data.google_project.project.project_id
  name         = "k8s-io-ingress-canary"
  address_type = "EXTERNAL"
}

// used by canary.k8s.io (IPv6)
resource "google_compute_global_address" "k8s_io_ingress_canary_v6" {
  project      = data.google_project.project.project_id
  name         = "k8s-io-ingress-canary-v6"
  address_type = "EXTERNAL"
  ip_version   = "IPV6"
}

// used by cs.k8s.io
resource "google_compute_global_address" "cs_k8s_io" {
  project      = data.google_project.project.project_id
  name         = "cs-k8s-io"
  address_type = "EXTERNAL"
}

// used by k8s-infra-prow.k8s.io
resource "google_compute_global_address" "k8s_infra_prow" {
  project      = data.google_project.project.project_id
  name         = "k8s-infra-prow"
  address_type = "EXTERNAL"
}

// used by k8s-infra-prow.k8s.io (IPv6)
resource "google_compute_global_address" "k8s_infra_prow_v6" {
  project      = data.google_project.project.project_id
  name         = "k8s-infra-prow-v6"
  address_type = "EXTERNAL"
  ip_version   = "IPV6"
}

// used by k8s.io
resource "google_compute_global_address" "k8s_io_ingress_prod" {
  project      = data.google_project.project.project_id
  name         = "k8s-io-ingress-prod"
  address_type = "EXTERNAL"
}

// used by k8s.io (IPv6)
resource "google_compute_global_address" "k8s_io_ingress_prod_v6" {
  project      = data.google_project.project.project_id
  name         = "k8s-io-ingress-prod-v6"
  address_type = "EXTERNAL"
  ip_version   = "IPV6"
}

// used by perf-dash.k8s.io
resource "google_compute_global_address" "perf_dash" {
  project      = data.google_project.project.project_id
  name         = "perf-dash-k8s-io-ingress-prod"
  address_type = "EXTERNAL"
}

// used by sippy.k8s.io
resource "google_compute_global_address" "sippy" {
  project      = data.google_project.project.project_id
  name         = "sippy-ingress-prod"
  description  = "IP for aaa cluster Ingress"
  address_type = "EXTERNAL"
}

// used by slack.k8s.io
resource "google_compute_global_address" "slack" {
  project      = data.google_project.project.project_id
  name         = "slack-infra-ingress-prod"
  address_type = "EXTERNAL"
}

// used by release.triage.k8s.io
resource "google_compute_global_address" "release_triage" {
  project      = data.google_project.project.project_id
  name         = "triage-party-release-ingress-prod"
  description  = "IP for aaa cluster Ingress"
  address_type = "EXTERNAL"
}
