/*
This file defines:
- GCS bucket to serve metrics bigquery results
- IAM bindings
*/

// Use a data source for the service account
data "google_service_account" "metrics_sa" {
  account_id = "k8s-metrics@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"
}

// Create a GCS bucket for metrics query results
resource "google_storage_bucket" "metrics_bucket" {
  name                        = "k8s-metrics"
  project                     = data.google_project.project.project_id
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 365 // days
    }
    action {
      type = "Delete"
    }
  }

}

data "google_iam_policy" "metrics_bucket_iam_bindings" {
  // Ensure prow owners have admin privileges, and keep existing
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
  // Ensure metrics service accounts have write access to the bucket
  binding {
    members = [
      "serviceAccount:${data.google_service_account.metrics_sa.email}",
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
  // Ensure metrics service accounts have write/update/delete access to objects
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "group:${local.prow_owners}",
      "serviceAccount:${data.google_service_account.metrics_sa.email}",
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
resource "google_storage_bucket_iam_policy" "metrics_bucket_iam_policy" {
  bucket      = google_storage_bucket.metrics_bucket.name
  policy_data = data.google_iam_policy.metrics_bucket_iam_bindings.policy_data
}

// Ensure metrics service account can run bigquery jobs by billing to this project
resource "google_project_iam_member" "k8s_metrics_sa_bigquery_user" {
  project = data.google_project.project.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${data.google_service_account.metrics_sa.email}"
}
