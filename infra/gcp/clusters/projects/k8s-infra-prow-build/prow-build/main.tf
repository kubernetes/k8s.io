/**
 * Copyright 2020 The Kubernetes Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
This file defines:
- GCP Project k8s-infra-prow-build to hold a prow build cluster
- GCP Service Account for k8s-infra-prow-build pods (bound via workload identity to a KSA of the same name)
- GCP Service Account for boskos-janitor (bound via workload identity to a KSA of the same name)
- GKE cluster configuration for prow-build
- GKE nodepool configuration for prow-build
*/

locals {
  project_id                         = "k8s-infra-prow-build"
  cluster_name                       = "prow-build"                       // The name of the cluster defined in this file
  cluster_location                   = "us-central1"                      // The GCP location (region or zone) where the cluster should be created
  bigquery_location                  = "US"                               // The bigquery specific location where the dataset should be created
  pod_namespace                      = "test-pods"                        // MUST match whatever prow is configured to use when it schedules to this cluster
  cluster_sa_name                    = "prow-build"                       // Name of the GSA and KSA that pods use by default
  boskos_janitor_sa_name             = "boskos-janitor"                   // Name of the GSA and KSA used by boskos-janitor
  scalability_tests_logs_bucket_name = "k8s-infra-scalability-tests-logs" // Name of the bucket for the scalability test results
}

data "google_organization" "org" {
  domain = "kubernetes.io"
}

module "project" {
  source       = "../../../modules/gke-project"
  project_id   = local.project_id
  project_name = local.project_id
}

// Ensure k8s-infra-prow-oncall@kuberentes.io has owner access to this project
resource "google_project_iam_member" "k8s_infra_prow_oncall" {
  project = local.project_id
  role    = "roles/owner"
  member  = "group:k8s-infra-prow-oncall@kubernetes.io"
}

// Role created by infra/gcp/ensure-organization.sh, use a data source to ensure it exists
data "google_iam_role" "prow_viewer" {
  name = "${data.google_organization.org.name}/roles/prow.viewer"
}

// Ensure k8s-infra-prow-viewers@kuberentes.io has prow.viewer access to this project
resource "google_project_iam_member" "k8s_infra_prow_viewers" {
  project = local.project_id
  role    = data.google_iam_role.prow_viewer.name
  member  = "group:k8s-infra-prow-viewers@kubernetes.io"
}

// Create GCP SA for pods
resource "google_service_account" "prow_build_cluster_sa" {
  project      = local.project_id
  account_id   = local.cluster_sa_name
  display_name = "Used by pods in '${local.cluster_name}' GKE cluster"
}
// Allow pods using the build cluster KSA to use the GCP SA via workload identity
data "google_iam_policy" "prow_build_cluster_sa_workload_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "serviceAccount:${local.project_id}.svc.id.goog[${local.pod_namespace}/${local.cluster_sa_name}]",
    ]
  }
}
// Authoritative iam-policy: replaces any existing policy attached to this service_account
resource "google_service_account_iam_policy" "prow_build_cluster_sa_iam" {
  service_account_id = google_service_account.prow_build_cluster_sa.name
  policy_data        = data.google_iam_policy.prow_build_cluster_sa_workload_identity.policy_data
}

// Create GCP SA for boskos-janitor
resource "google_service_account" "boskos_janitor_sa" {
  project      = local.project_id
  account_id   = local.boskos_janitor_sa_name
  display_name = "Used by ${local.boskos_janitor_sa_name} in '${local.cluster_name}' GKE cluster"
}
// Allow pods using the build cluster KSA to use the GCP SA via workload identity
data "google_iam_policy" "boskos_janitor_sa_workload_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "serviceAccount:${local.project_id}.svc.id.goog[${local.pod_namespace}/${local.boskos_janitor_sa_name}]",
    ]
  }
}
// Authoritative iam-policy: replaces any existing policy attached to this service account
resource "google_service_account_iam_policy" "boskos_janitor_sa_iam" {
  service_account_id = google_service_account.boskos_janitor_sa.name
  policy_data        = data.google_iam_policy.boskos_janitor_sa_workload_identity.policy_data
}

// external ip formerly managed by infra/gcp/prow/ensure-e2e-projects.sh
resource "google_compute_address" "boskos_metrics" {
  name         = "boskos-metrics"
  description  = "to allow monitoring.k8s.prow.io to scrape boskos metrics"
  project      = local.project_id
  region       = local.cluster_location
  address_type = "EXTERNAL"
}

// external ip formerly managed by infra/gcp/prow/ensure-e2e-projects.sh
resource "google_compute_address" "greenhouse_metrics" {
  name         = "greenhouse-metrics"
  description  = "to allow monitoring.k8s.prow.io to scrape greenhouse metrics"
  project      = local.project_id
  region       = local.cluster_location
  address_type = "EXTERNAL"
}

module "prow_build_cluster" {
  source             = "../../../modules/gke-cluster"
  project_name       = local.project_id
  cluster_name       = local.cluster_name
  cluster_location   = local.cluster_location
  bigquery_location  = local.bigquery_location
  is_prod_cluster    = "true"
  release_channel    = "REGULAR"
  dns_cache_enabled  = "true"
  cloud_shell_access = false
}

module "prow_build_nodepool_n1_highmem_8_maxiops" {
  source        = "../../../modules/gke-nodepool"
  project_name  = local.project_id
  cluster_name  = module.prow_build_cluster.cluster.name
  location      = module.prow_build_cluster.cluster.location
  name          = "pool4"
  initial_count = 1
  min_count     = 1
  max_count     = 80
  # kind-ipv6 jobs need an ipv6 stack; COS doesn't provide one, so we need to
  # use an UBUNTU image instead. Keep parity with the existing google.com
  # k8s-prow-builds/prow cluster by using the CONTAINERD variant
  image_type   = "UBUNTU_CONTAINERD"
  machine_type = "n1-highmem-8"
  # Use an ssd volume sized to allow the max IOPS supported by n1 instances w/ 8 vCPU
  disk_size_gb    = 500
  disk_type       = "pd-ssd"
  service_account = module.prow_build_cluster.cluster_node_sa.email
}

module "greenhouse_nodepool" {
  source       = "../../../modules/gke-nodepool"
  project_name = local.project_id
  cluster_name = module.prow_build_cluster.cluster.name
  location     = module.prow_build_cluster.cluster.location
  name         = "greenhouse"
  labels       = { dedicated = "greenhouse" }
  # NOTE: taints are only applied during creation and ignored after that, see module docs
  taints        = [{ key = "dedicated", value = "greenhouse", effect = "NO_SCHEDULE" }]
  initial_count = 1
  min_count     = 1
  max_count     = 1
  # choosing this image for parity with the build nodepool
  image_type = "UBUNTU_CONTAINERD"
  # choosing a machine type to maximize IOPs
  machine_type    = "n1-standard-32"
  disk_size_gb    = 100
  disk_type       = "pd-standard"
  service_account = module.prow_build_cluster.cluster_node_sa.email
}


// Bucket for scalability tests results
resource "google_storage_bucket" "scalability_tests_logs" {
  project = local.project_id
  name    = local.scalability_tests_logs_bucket_name

  uniform_bucket_level_access = true
}

data "google_iam_policy" "scalability_tests_logs_bindings" {
  // Ensure k8s-infra-prow-oncall has admin privileges, and keep existing
  // legacy bindings since we're overwriting all existing bindings below
  binding {
    members = [
      "group:k8s-infra-prow-oncall@kubernetes.io",
    ]
    role = "roles/storage.admin"
  }
  binding {
    members = [
      "group:k8s-infra-prow-oncall@kubernetes.io",
      "projectEditor:${local.project_id}",
      "projectOwner:${local.project_id}",
    ]
    role = "roles/storage.legacyBucketOwner"
  }
  binding {
    members = [
      "projectViewer:${local.project_id}",
    ]
    role = "roles/storage.legacyBucketReader"
  }
  // Ensure prow-build serviceaccount can write to bucket
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "serviceAccount:${google_service_account.prow_build_cluster_sa.email}",
    ]
  }
  // Ensure bucket is world readable
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "allUsers"
    ]
  }
}

// Authoritative iam-policy: replaces any existing policy attached to the bucket
resource "google_storage_bucket_iam_policy" "scalability_tests_logs_policy" {
  bucket      = google_storage_bucket.scalability_tests_logs.name
  policy_data = data.google_iam_policy.scalability_tests_logs_bindings.policy_data
}
