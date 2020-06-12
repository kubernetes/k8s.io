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
- Google Project k8s-infra-prow-build-trusted to host the cluster
- GCP Service Account for prow-build-trusted
- GKE cluster configuration for prow-build-trusted
- GKE nodepool configuration for prow-build-trusted
*/

locals {
  project_id              = "k8s-infra-prow-build-trusted"
  cluster_name            = "prow-build-trusted"  // The name of the cluster defined in this file
  cluster_location        = "us-central1"         // The GCP location (region or zone) where the cluster should be created
  bigquery_location       = "US"                  // The bigquery specific location where the dataset should be created
  pod_namespace           = "test-pods"           // MUST match whatever prow is configured to use when it schedules to this cluster
  cluster_sa_name         = "prow-build-trusted"  // Name of the GSA and KSA that pods use by default
  gcb_builder_sa_name     = "gcb-builder"         // Name of the GSA and KSA that pods use to be allowed to run GCB builds and push to GCS buckets
  prow_deployer_sa_name   = "prow-deployer"       // Name of the GSA and KSA that pods use to be allowed to deploy to prow build clusters
}

module "project" {
  source = "../../../modules/gke-project"
  project_id            = local.project_id
  project_name          = local.project_id
}

// Ensure k8s-infra-prow-oncall@kuberentes.io has owner access to this project
resource "google_project_iam_member" "k8s_infra_prow_oncall" {
  project = local.project_id
  role    = "roles/owner"
  member  = "group:k8s-infra-prow-oncall@kubernetes.io"
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

// Create GCP SA for jobs that use GCB and push results to GCS
resource "google_service_account" "gcb_builder_sa" {
  project      = local.project_id
  account_id   = local.gcb_builder_sa_name
  display_name = local.gcb_builder_sa_name
}
// Allow pods using the build cluster KSA to use the GCP SA via workload identity
data "google_iam_policy" "gcb_builder_sa_workload_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "serviceAccount:${local.project_id}.svc.id.goog[${local.pod_namespace}/${local.gcb_builder_sa_name}]",
    ]
  }
}
// Authoritative iam-policy: replaces any existing policy attached to this service_account
resource "google_service_account_iam_policy" "gcb_builder_sa_iam" {
  service_account_id = google_service_account.gcb_builder_sa.name
  policy_data        = data.google_iam_policy.gcb_builder_sa_workload_identity.policy_data
}

// Create GCP SA for jobs that deploy to k8s-infra prow clusters
resource "google_service_account" "prow_deployer_sa" {
  project      = local.project_id
  account_id   = local.prow_deployer_sa_name
  display_name = local.prow_deployer_sa_name
}
// Allow pods using the build cluster KSA to use the GCP SA via workload identity
data "google_iam_policy" "prow_deployer_sa_workload_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "serviceAccount:${local.project_id}.svc.id.goog[${local.pod_namespace}/${local.prow_deployer_sa_name}]",
    ]
  }
}
// Authoritative iam-policy: replaces any existing policy attached to this service_account
resource "google_service_account_iam_policy" "prow_deployer_sa_iam" {
  service_account_id = google_service_account.prow_deployer_sa.name
  policy_data        = data.google_iam_policy.prow_deployer_sa_workload_identity.policy_data
}

resource "google_project_iam_member" "prow_deployer_for_prow_build_trusted" {
  project = local.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${local.prow_deployer_sa_name}@${local.project_id}.iam.gserviceaccount.com"
}
resource "google_project_iam_member" "prow_deployer_for_prow_build" {
  project = "k8s-infra-prow-build"
  role    = "roles/container.developer"
  member  = "serviceAccount:${local.prow_deployer_sa_name}@${local.project_id}.iam.gserviceaccount.com"
}

module "prow_build_cluster" {
  source = "../../../modules/gke-cluster"
  project_name      = local.project_id
  cluster_name      = local.cluster_name
  cluster_location  = local.cluster_location
  bigquery_location = local.bigquery_location
  is_prod_cluster   = "true"
}

module "prow_build_nodepool" {
  source = "../../../modules/gke-nodepool"
  project_name    = local.project_id
  cluster_name    = module.prow_build_cluster.cluster.name
  location        = module.prow_build_cluster.cluster.location
  name            = "trusted-pool1"
  initial_count   = 1
  min_count       = 1
  max_count       = 3
  machine_type    = "n1-standard-8"
  disk_size_gb    = 200
  disk_type       = "pd-standard"
  service_account = module.prow_build_cluster.cluster_node_sa.email
}

