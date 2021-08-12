/*
This file defines:
- bigquery dataset for triage to store temp results
- GCS bucket to serve go.k8s.io/triage results
- IAM bindings
*/

locals {
  // TODO(spiffxp): remove legacy serviceaccount when migration completed
  triage_legacy_sa_email = "triage@k8s-gubernator.iam.gserviceaccount.com"
  triage_dataset               = "k8s-triage"
  prow_owners                  = "k8s-infra-prow-oncall@kubernetes.io"
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
  location                    = "us-central1"
  storage_class               = "REGIONAL"
  uniform_bucket_level_access = true
}

data "google_iam_policy" "triage_bucket_iam_bindings" {
  // Ensure k8s-infra-prow-oncall has admin privileges, and keep existing
  // legacy bindings since we're overwriting all existing bindings below
  binding {
    members = [
      "group:${local.prow_owners}",
    ]
    role = "roles/storage.admin"
  }
  // Preserve legacy storage bindings, give storage.admim members legacy bucket owner
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
resource "google_project_iam_member" "k8s_triage_sa_bigquery_user" {
  project = data.google_project.project.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${data.google_service_account.triage_sa.email}"
}
