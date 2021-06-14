

/**
 * Copyright 2021 The Kubernetes Authors
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


/* TODO(ameukam): This not working. possible conflict between both bindings
data "google_iam_policy" "storage_policy_objectadmin" {
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "group:cloud-storage-analytics@google.com",
    ]
  }
}

resource "google_storage_bucket_iam_policy" "analytics_objectadmin_policy" {
  bucket      = google_storage_bucket.audit-logs-gcs.name
  policy_data = data.google_iam_policy.storage_policy_objectadmin.policy_data
}



data "google_iam_policy" "storage_policy_legacybucketwriter" {
  binding {
    role = "roles/storage.legacyBucketWriter"
    members = [
      "group:cloud-storage-analytics@google.com",
    ]
  }
}

resource "google_storage_bucket_iam_policy" "analytics_legacybucketwriter_policy" {
  bucket      = google_storage_bucket.audit-logs-gcs.name
  policy_data = data.google_iam_policy.storage_policy_legacybucketwriter.policy_data
} */

// Allow ready-only access to k8s-infra-gcs-access-logs@kubernetes.io
resource "google_storage_bucket_iam_member" "artificats-gcs-logs" {
  bucket = google_storage_bucket.audit-logs-gcs.name
  role   = "roles/storage.objectViewer"
  member = "group:k8s-infra-gcs-access-logs@kubernetes.io"
}
