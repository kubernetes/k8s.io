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
  project_id              = "k8s-infra-prow-build"
  cluster_name            = "prow-build"           // The name of the cluster defined in this file
  cluster_location        = "us-central1"          // The GCP location (region or zone) where the cluster should be created
  bigquery_location       = "US"                   // The bigquery specific location where the dataset should be created
  pod_namespace           = "test-pods"            // MUST match whatever prow is configured to use when it schedules to this cluster
  cluster_sa_name         = "prow-build"           // Name of the GSA and KSA that pods use by default
  boskos_janitor_sa_name  = "boskos-janitor"       // Name of the GSA and KSA used by boskos-janitor
}

// TODO: I think more people than me should have owner/edit access to this project
module "project" {
  source = "../../../modules/k8s-infra-gke-project"
  project_id            = local.project_id
  project_name          = local.project_id
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

module "prow_build_cluster" {
  source = "../../../modules/k8s-infra-gke-cluster"
  project_name      = local.project_id
  cluster_name      = local.cluster_name
  cluster_location  = local.cluster_location
  bigquery_location = local.bigquery_location
  is_prod_cluster   = "true"
}

module "prow_build_nodepool" {
  source = "../../../modules/k8s-infra-gke-nodepool"
  project_name    = local.project_id
  cluster_name    = module.prow_build_cluster.cluster.name
  location        = module.prow_build_cluster.cluster.location
  name            = "pool1"
  min_count       = 2
  max_count       = 6
  # kind-ipv6 jobs need an ipv6 stack; COS doesn't provide one, so we need to
  # use an UBUNTU image instead. Why the CONTAINERD variant? I don't know, but
  # it's what k8s-prow-builds/prow (prow.k8s.io's existing google.com build 
  # cluster) is using today, so we're just going to follow that
  image_type      = "UBUNTU_CONTAINERD"
  machine_type    = "n1-highmem-8"
  disk_size_gb    = 250
  disk_type       = "pd-ssd"
  service_account = module.prow_build_cluster.cluster_node_sa.email
}
