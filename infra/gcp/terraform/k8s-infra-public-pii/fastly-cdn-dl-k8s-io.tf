/*
Copyright 2023 The Kubernetes Authors.

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
This file contains
- the BigQuery dataset and table for cdn.dl.k8s.io logging
- The IAM configuration to allow Fastly SA write permissions on a dataset
*/

locals {
  cdn_dl_k8s_io_logging_dataset_id = "fastly_bigquery_cdn_dl_k8s_io"
  fastly_sa                        = "fastly-logging@datalog-bulleit-9e86.iam.gserviceaccount.com"
}

resource "google_service_account" "fastly_logging_sa" {
  project = google_project.project.project_id
  account_id = "fastly-bigquery-logging-sa"
  display_name = "Fastly BigQuery Logging SA"
}

# https://docs.fastly.com/en/guides/configuring-google-iam-servic e-account-impersonation-for-fastly-logging
resource "google_service_account_iam_member" "cloudbuild_terraform_sa_impersonate_permissions" {
  service_account_id = google_service_account.fastly_logging_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${local.fastly_sa}"
}

resource "google_bigquery_dataset" "fastly_cdn_dl_k8s_io_logging" {
  project                     = google_project.project.project_id
  dataset_id                  = local.cdn_dl_k8s_io_logging_dataset_id
  friendly_name               = local.cdn_dl_k8s_io_logging_dataset_id
  delete_contents_on_destroy  = true
  default_table_expiration_ms = 400 * 24 * 60 * 60 * 1000 # 400 days
  location                    = "US"
}

resource "google_bigquery_table" "fastly_cdn_dl_k8s_io_logs" {
  project    = google_project.project.project_id
  dataset_id = local.cdn_dl_k8s_io_logging_dataset_id
  table_id   = "${local.cdn_dl_k8s_io_logging_dataset_id}_logs"

  schema = file("${path.module}/files/fastly_cdn_dl_k8s_io_logs.json")

  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.fastly_cdn_dl_k8s_io_logging
  ]
}

resource "google_bigquery_dataset_iam_member" "cdn_dl_k8s_io_logging" {
  project    = google_project.project.project_id
  dataset_id = google_bigquery_dataset.fastly_cdn_dl_k8s_io_logging.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.fastly_logging_sa.email}"

  depends_on = [
    google_bigquery_dataset.fastly_cdn_dl_k8s_io_logging
  ]
}
