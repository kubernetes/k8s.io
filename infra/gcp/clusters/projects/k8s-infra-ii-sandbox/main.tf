
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
     project_id = "k8s-infra-ii-sandbox"
 }


data "google_billing_account" "account" {
  billing_account = "018801-93540E-22A20E"
}

data "google_organization" "org" {
  domain = "kubernetes.io"
}

resource "google_project" "project" {
    name = local.project_id
    project_id = local.project_id
    org_id = data.google_organization.org.org_id
    billing_account = data.google_billing_account.account.id
}


resource "google_project_service" "project" {
  project = google_project.project.id

  for_each = toset([
    "cloudbuild.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerregistry.googleapis.com",
    "storage-component.googleapis.com"
  ])

  service = each.key
}

// Ensure k8s-infra-ii-coop@kubernetes.io has editor access to this project
resource "google_project_iam_member" "k8s_infra_ii_coop" {
  project = google_project.project.id
  role    = "roles/owner"
  member  = "group:k8s-infra-ii-coop@kubernetes.io"
}

// Ensure bq-data-transfer@k8s-infra-public-pii.iam.gserviceaccount.com to get read-only access
// to the BQ dataset riaan_data_store.
data "google_service_account" "bq_data_transfer" {
  account_id = "bq-data-transfer"
  project = "k8s-infra-public-pii"
}

resource "google_bigquery_dataset_iam_member" "bq_data_transfer_binding" {
  project    = local.project_id
  dataset_id = "riaan_data_store"
  role       = "roles/bigquery.admin"
  member     = "serviceAccount:${data.google_service_account.bq_data_transfer.email}"
}
