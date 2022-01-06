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
- bigquery dataset for triage to store temp results
- GCS bucket to serve go.k8s.io/triage results
- IAM bindings
*/

locals {
  // TODO(spiffxp): remove legacy serviceaccount when migration completed
  triage_legacy_sa_email = "triage@k8s-gubernator.iam.gserviceaccount.com"
}

// Use a data source for the service account
// NB: we can't do this for triage_legacy_sa_email as we lack sufficient privileges
data "google_service_account" "triage_sa" {
  account_id = "k8s-triage@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"
}

// Create a GCS bucket for triage results
resource "google_storage_bucket" "triage_bucket" {
  name                        = "k8s-triage"
  project                     = data.google_project.project.project_id
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
}

data "google_iam_policy" "triage_bucket_iam_bindings" {
  // Ensure prow owners have admin privileges, and keep existing
  // legacy bindings since we're overwriting all existing bindings below
  binding {
    members = [
      "group:${local.prow_owners}",
    ]
    role = "roles/storage.admin"
  }
  // Preserve legacy storage bindings, give storage.admin members legacy bucket owner
  binding {
    members = [
      "group:${local.prow_owners}",
      "projectEditor:${data.google_project.project.project_id}",
      "projectOwner:${data.google_project.project.project_id}",
    ]
    role = "roles/storage.legacyBucketOwner"
  }
  // Ensure triage service accounts have write access to the bucket
  binding {
    members = [
      "serviceAccount:${data.google_service_account.triage_sa.email}",
      "serviceAccount:${local.triage_legacy_sa_email}"
    ]
    role = "roles/storage.legacyBucketWriter"
  }
  // Preserve legacy storage bindings
  binding {
    members = [
      "projectViewer:${data.google_project.project.project_id}",
    ]
    role = "roles/storage.legacyBucketReader"
  }
  // Ensure triage service accounts have write/update/delete access to objects
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "group:${local.prow_owners}",
      "serviceAccount:${data.google_service_account.triage_sa.email}",
      "serviceAccount:${local.triage_legacy_sa_email}"
    ]
  }
  // Ensure bucket contents are world readable
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "allUsers"
    ]
  }
}

// Authoritative iam-policy: replaces any existing policy attached to the bucket
resource "google_storage_bucket_iam_policy" "triage_bucket_iam_policy" {
  bucket      = google_storage_bucket.triage_bucket.name
  policy_data = data.google_iam_policy.triage_bucket_iam_bindings.policy_data
}

// Ensure triage service account can run bigquery jobs by billing to this project
resource "google_project_iam_member" "triage_sa_bigquery_user" {
  project = data.google_project.project.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${data.google_service_account.triage_sa.email}"
}

// BigQuery dataset for triage to store temporary results
resource "google_bigquery_dataset" "triage_dataset" {
  dataset_id  = "k8s_triage"
  project     = data.google_project.project.project_id
  description = "Dataset for kubernetes/test-infra/triage to store temporary results"
  location    = "US"

  // Data is precious, make it difficult to delete by accident
  delete_contents_on_destroy = false
}

data "google_iam_policy" "triage_dataset_iam_policy" {
  binding {
    members = [
      "group:${local.prow_owners}",
    ]
    role = "roles/bigquery.dataOwner"
  }
  binding {
    members = [
      "serviceAccount:${data.google_service_account.triage_sa.email}",
    ]
    role = "roles/bigquery.dataEditor"
  }
}

resource "google_bigquery_dataset_iam_policy" "triage_dataset" {
  dataset_id  = google_bigquery_dataset.triage_dataset.dataset_id
  project     = google_bigquery_dataset.triage_dataset.project
  policy_data = data.google_iam_policy.triage_dataset_iam_policy.policy_data
}
