/*
Copyright 2026 The Kubernetes Authors.

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
- A read-only service account used to collect billing data
- IAM bindings allowing it to run BigQuery jobs and read the
  kubernetes_public_billing dataset
- A service account key stored in Secret Manager

NOTE: the kubernetes_public_billing dataset itself is not managed by
terraform, it is created by infra/gcp/bash/ensure-main-project.sh
*/

resource "google_service_account" "k8s_cost" {
  account_id   = "k8s-cost"
  display_name = "k8s-cost billing collector (read-only)"
  project      = data.google_project.project.project_id
}

// Allow the service account to run BigQuery jobs (queries) in this project
resource "google_project_iam_member" "k8s_cost_jobuser_binding" {
  project = data.google_project.project.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.k8s_cost.email}"
}

// Allow the service account to read the billing dataset
resource "google_bigquery_dataset_iam_member" "k8s_cost_billing_viewer" {
  project    = data.google_project.project.project_id
  dataset_id = "kubernetes_public_billing"
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.k8s_cost.email}"
}

resource "google_service_account_key" "k8s_cost" {
  service_account_id = google_service_account.k8s_cost.id
}

resource "google_secret_manager_secret" "k8s_cost_sa_key" {
  project   = data.google_project.project.project_id
  secret_id = "k8s-cost-sa-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "k8s_cost_sa_key" {
  secret      = google_secret_manager_secret.k8s_cost_sa_key.id
  secret_data = base64decode(google_service_account_key.k8s_cost.private_key)
}
