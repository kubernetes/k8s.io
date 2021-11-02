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
- GCS bucket to serve KEP reports
- IAM bindings
*/

locals {
  keps_owners = "k8s-infra-keps@kubernetes.io"
}

// Use a data source for the service account
data "google_service_account" "keps_sa" {
  account_id = "k8s-keps@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"
}

// Create a GCS bucket for KEP reports
resource "google_storage_bucket" "keps_bucket" {
  name                        = "k8s-keps"
  project                     = data.google_project.project.project_id
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
}

data "google_iam_policy" "keps_bucket_iam_bindings" {
  // Ensure prow owners have admin privileges, and keep existing
  // legacy bindings since we're overwriting all existing bindings below
  binding {
    members = [
      "group:${local.prow_owners}",
      "group:${local.keps_owners}",
    ]
    role = "roles/storage.admin"
  }
  // Preserve legacy storage bindings, give storage.admin members legacy bucket owner
  binding {
    members = [
      "group:${local.prow_owners}",
      "group:${local.keps_owners}",
      "projectEditor:${data.google_project.project.project_id}",
      "projectOwner:${data.google_project.project.project_id}",
    ]
    role = "roles/storage.legacyBucketOwner"
  }
  // Ensure keps service accounts have write access to the bucket
  binding {
    members = [
      "serviceAccount:${data.google_service_account.keps_sa.email}",
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
  // Ensure keps service accounts have write/update/delete access to objects
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "group:${local.prow_owners}",
      "group:${local.keps_owners}",
      "serviceAccount:${data.google_service_account.keps_sa.email}",
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
resource "google_storage_bucket_iam_policy" "keps_bucket_iam_policy" {
  bucket      = google_storage_bucket.keps_bucket.name
  policy_data = data.google_iam_policy.keps_bucket_iam_bindings.policy_data
}
