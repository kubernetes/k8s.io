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

locals {
  project_id  = "k8s-infra-public-pii"
  bucket_name = "k8s-infra-artifacts-gcslogs"
  dataset-id  = replace(local.bucket_name, "-", "_")
}


data "google_billing_account" "account" {
  billing_account = "018801-93540E-22A20E"
}

data "google_organization" "org" {
  domain = "kubernetes.io"
}


resource "google_project" "project" {
  name            = local.project_id
  project_id      = local.project_id
  org_id          = data.google_organization.org.org_id
  billing_account = data.google_billing_account.account.id
}

resource "google_project_service" "project" {
  project = google_project.project.id

  for_each = toset([
    "bigquery.googleapis.com",
    "bigqueryreservation.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "storage-component.googleapis.com"
  ])

  service = each.key
}


// BigQuery dataset for audit logs
resource "google_bigquery_dataset" "audit-logs-gcs" {
  dataset_id                  = local.dataset-id
  friendly_name               = local.dataset-id
  delete_contents_on_destroy  = false
  default_table_expiration_ms = 34560000000 #30 days
  location                    = "US"
  project                     = google_project.project.project_id
}


# A bucket to store logs in audit logs for GCS
resource "google_storage_bucket" "audit-logs-gcs" {
  name          = local.bucket_name
  project       = google_project.project.project_id
  storage_class = "REGIONAL"
  location      = "us-central1"

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 400
    }
  }

  // NOTE: Prevent the bucket from being deleted
  lifecycle {
    prevent_destroy = true
  }
}

// service account for running ASN etl pipeline job
resource "google_service_account" "asn_etl" {
  project      = local.project_id
  account_id   = "asn-etl"
  display_name = "asn-etl"
}

// service account for running ASN etl pipeline job
data "google_service_account" "ii_sandbox_asn_etl" {
  account_id = "asn-etl"
  project    = "k8s-infra-ii-sandbox"
}

data "google_iam_policy" "audit_logs_gcs_bindings" {
  // Allow GCP org admins to admin this bucket
  binding {
    role = "roles/storage.admin"
    members = [
      "group:k8s-infra-gcp-org-admins@google.com",
    ]
  }
  // Allow GCS access logs to be written to this bucket
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "group:cloud-storage-analytics@google.com",
    ]
  }
  binding {
    role = "roles/storage.legacyBucketWriter"
    members = [
      "group:cloud-storage-analytics@google.com",
    ]
  }
  // Allow read-only access to authorized service accounts
  binding {
    role = "roles/storage.legacyObjectReader"
    members = [
      "serviceAccount:${google_service_account.asn_etl.email}",
      "serviceAccount:${data.google_service_account.ii_sandbox_asn_etl.email}",
    ]
  }
  binding {
    role = "roles/storage.legacyBucketReader"
    members = [
      "serviceAccount:${google_service_account.asn_etl.email}",
      "serviceAccount:${data.google_service_account.ii_sandbox_asn_etl.email}",
    ]
  }
  // Allow read-only access to k8s-infra-gcs-access-logs@kubernetes.io
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "group:k8s-infra-gcs-access-logs@kubernetes.io"
    ]
  }
}

resource "google_storage_bucket_iam_policy" "analytics_objectadmin_policy" {
  bucket      = google_storage_bucket.audit-logs-gcs.name
  policy_data = data.google_iam_policy.audit_logs_gcs_bindings.policy_data
}
