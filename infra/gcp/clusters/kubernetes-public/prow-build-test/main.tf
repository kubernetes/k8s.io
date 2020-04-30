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
- GCP Service Account for prow-build-test
- GCP Service Account for boskos-jenkins
- GKE cluster configuration for prow-build-test
- GKE nodepool configuration for prow-build-test
*/

locals {
  project_name            = "kubernetes-public"
  cluster_name            = "prow-build-test"     // The name of the cluster defined in this file
  cluster_ksa_name        = "prow-build"          // MUST match the name of the KSA intended to use the prow_build_cluster_sa serviceaccount
  cluster_location        = "us-central1"         // The GCP location (region or zone) where the cluster should be created
  bigquery_location       = "US"                  // The bigquery specific location where the dataset should be created
  pod_namespace           = "test-pods"           // MUST match whatever prow is configured to use when it schedules to this cluster
  boskos_janitor_gsa_name = "boskos-janitor-test" // The name of the GCP SA used by boskos-janitor
  boskos_janitor_ksa_name = "boskos-janitor"      // MUST match the name of the KSA intended to use the boskos_janitor_sa serviceaccount
}

// This configures the source project where we should install the cluster
data "google_project" "project" {
  project_id = local.project_name
}

// Create GCP SA for pods
resource "google_service_account" "prow_build_cluster_sa" {
  project      = data.google_project.project.name
  account_id   = local.cluster_name
  display_name = "Used by pods in '${local.cluster_name}' GKE cluster"
}
// Allow pods using the build cluster KSA to use the GCP SA via workload identity
data "google_iam_policy" "prow_build_cluster_sa_workload_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "serviceAccount:${data.google_project.project.name}.svc.id.goog[${local.pod_namespace}/${local.cluster_ksa_name}]",
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
  project      = data.google_project.project.name
  account_id   = local.boskos_janitor_gsa_name
  display_name = "Used by boskos-janitor in '${local.cluster_name}' GKE cluster"
}
// Allow pods using the build cluster KSA to use the GCP SA via workload identity
data "google_iam_policy" "boskos_janitor_sa_workload_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "serviceAccount:${data.google_project.project.name}.svc.id.goog[${local.pod_namespace}/${local.boskos_janitor_ksa_name}]",
    ]
  }
}
// Authoritative iam-policy: replaces any existing policy attached to this service account
resource "google_service_account_iam_policy" "boskos_janitor_sa_iam" {
  service_account_id = google_service_account.boskos_janitor_sa.name
  policy_data        = data.google_iam_policy.boskos_janitor_sa_workload_identity.policy_data
}

module "prow_build_test_cluster" {
  source = "./k8s-infra-gke-cluster"
  project_name      = data.google_project.project.name
  cluster_name      = local.cluster_name
  cluster_location  = local.cluster_location
  bigquery_location = local.bigquery_location
}

module "prow_build_test_nodepool" {
  source = "./k8s-infra-gke-nodepool"
  project_name    = data.google_project.project.name
  cluster_name    = module.prow_build_test_cluster.cluster.name
  location        = module.prow_build_test_cluster.cluster.location
  name            = "pool1"
  min_count       = 1
  max_count       = 3
  // k8s-prow-builds uses n1-highmem-8
  machine_type    = "n1-highmem-2"
  // k8s-prow-builds uses 250
  disk_size_gb    = 100
  disk_type       = "pd-ssd"
  service_account = module.prow_build_test_cluster.cluster_node_sa.email
}
