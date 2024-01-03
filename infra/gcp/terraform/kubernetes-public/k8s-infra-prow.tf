/*
Copyright 2021 The Kubernetes Authors.

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

/*
This file defines:
- a bucket for k8s-infra-prow
- a GCP service account for the bucket
- IAM bindings for the bucket
- a Secret Manager secret for the service account key
*/

locals {
  bucket_name               = "k8s-infra-prow-results"
  bucket_location           = "us-central1"
  prow_service_account      = "k8s-infra-prow"
  test_pods_namespace       = "k8s-infra-test-pods"
  test_pods_service_account = "prowjob-default-sa"
}


// Create GCP Service Account for prow control plane
resource "google_service_account" "k8s_infra_prow" {
  project      = data.google_project.project.project_id
  account_id   = local.prow_service_account
  display_name = local.prow_service_account
}

// Allow pods using the build cluster KSA to use the GCP SA k8s-infra-prow via workload identity
resource "google_service_account_iam_member" "prow_build_cluster_sa_iam" {
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.k8s_infra_prow.name
  member             = format("serviceAccount:%s.svc.id.goog[%s/%s]", "k8s-infra-prow-build", local.test_pods_namespace, local.test_pods_service_account)
}

// Allow pods using the build cluster KSA to use the GCP SA k8s-infra-prow via workload identity
resource "google_service_account_iam_member" "prow_build_trusted_cluster_sa_iam" {
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.k8s_infra_prow.name
  member             = format("serviceAccount:%s.svc.id.goog[%s/%s]", "k8s-infra-prow-build-trusted", local.test_pods_namespace, local.test_pods_service_account)
}

// Allow deck (component of k8s-infra-prow) service account to use GCP SA k8s-infra-prow via workload identity
// TODO (ameukam): move hardcoded value to terraform variables
resource "google_service_account_iam_member" "aaa_cluster_sa_iam" {
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.k8s_infra_prow.name
  member             = format("serviceAccount:%s.svc.id.goog[%s/%s]", "kubernetes-public", "prow", "deck")
}

// Create a GCS bucket for ProwJobs logs and tide history
resource "google_storage_bucket" "k8s_infra_prow_bucket" {
  name          = local.bucket_name
  project       = data.google_project.project.project_id
  storage_class = "REGIONAL"
  location      = local.bucket_location

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
}

// Allow GCP SA k8s-infra-prow admin for the objects in the bucket k8s-infra-prow-results
resource "google_storage_bucket_iam_member" "k8s_infra_prow_admin" {
  bucket = google_storage_bucket.k8s_infra_prow_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.k8s_infra_prow.email}"
}

// Allow GCP SA k8s-infra-prow admin (legacy role) for the objects in the bucket k8s-infra-prow-results
resource "google_storage_bucket_iam_member" "k8s_infra_prow_admin_legacy" {
  bucket = google_storage_bucket.k8s_infra_prow_bucket.name
  role   = "roles/storage.legacyBucketWriter"
  member = "serviceAccount:${google_service_account.k8s_infra_prow.email}"
}

// Allow the bucket k8s-infra-prow-results to be word-readable
resource "google_storage_bucket_iam_member" "k8s_infra_prow_public_access" {
  bucket = google_storage_bucket.k8s_infra_prow_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

// Allow read access to prow owners
resource "google_storage_bucket_iam_member" "k8s_infra_prow_owners" {
  bucket = google_storage_bucket.k8s_infra_prow_bucket.name
  role   = "roles/storage.objectViewer"
  //TODO(ameukam): switch to allUsers when https://github.com/kubernetes/k8s.io/issues/752 is closed.
  member = "group:${local.prow_owners}"
}
