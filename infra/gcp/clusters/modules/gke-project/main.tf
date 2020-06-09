/**
 * Copyright 2020 The Kubernetes Authors
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

/// Create the project in which we're creating the cluster
resource "google_project" "project" {
  name            = var.project_name
  project_id      = var.project_name
  org_id          = "758905017065"          // kubernetes.io
  billing_account = "018801-93540E-22A20E"
}

// Services we need
resource "google_project_service" "compute" {
  project = google_project.project.project_id
  service = "compute.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "logging" {
  project = google_project.project.project_id
  service = "logging.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "monitoring" {
  project = google_project.project.project_id
  service = "monitoring.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "bigquery" {
  project = google_project.project.project_id
  service = "bigquery.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "container" {
  project = google_project.project.project_id
  service = "container.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "storage_component" {
  project = google_project.project.project_id
  service = "storage-component.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "oslogin" {
  project = google_project.project.project_id
  service = "oslogin.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "cloudbuild" {
  project = google_project.project.project_id
  service = "cloudbuild.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "stackdriver" {
  project = google_project.project.project_id
  service = "stackdriver.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "secretmanager" {
  project = google_project.project.project_id
  service = "secretmanager.googleapis.com"
  disable_dependent_services = true
}


// "Empower cluster admins" is what ensure-main-project.sh says
resource "google_project_iam_member" "cluster_admins_as_compute_viewer" {
  project = google_project.project.project_id
  role    = "roles/compute.viewer"
  member  = "group:${var.cluster_admins_group}"
}
resource "google_project_iam_member" "cluster_admins_as_container_admin" {
  project = google_project.project.project_id
  role    = "roles/container.admin"
  member  = "group:${var.cluster_admins_group}"
}
resource "google_project_iam_custom_role" "service_account_lister" {
  project     = google_project.project.project_id
  role_id     = "ServiceAccountLister"
  title       = "Service Account Lister"
  description = "Can list ServiceAccounts."
  permissions = ["iam.serviceAccounts.list"]
}
resource "google_project_iam_member" "cluster_admins_as_service_account_lister" {
  project = google_project.project.project_id
  role    = "projects/${google_project.project.project_id}/roles/${google_project_iam_custom_role.service_account_lister.role_id}"
  member  = "group:${var.cluster_admins_group}"
}

// "Empowering cluster users" is what ensure-main-project.sh says
resource "google_project_iam_member" "cluster_users_as_container_cluster_viewer" {
  project = google_project.project.project_id
  role    = "roles/container.clusterViewer"
  member  = "group:${var.cluster_users_group}"
}
