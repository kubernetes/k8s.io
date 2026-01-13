/*
Copyright 2025 The Kubernetes Authors.

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
- GCP project for centralized observability infrastructure
- Required APIs
- IAM bindings for admin and viewer groups
*/

locals {
  project_id = "k8s-infra-observability"
}

data "google_billing_account" "account" {
  billing_account = "018801-93540E-22A20E"
}

data "google_organization" "org" {
  domain = "kubernetes.io"
}

// Create the observability project
resource "google_project" "project" {
  name            = local.project_id
  project_id      = local.project_id
  org_id          = data.google_organization.org.org_id
  billing_account = data.google_billing_account.account.id
}

// Enable required GCP APIs
resource "google_project_service" "services" {
  project = google_project.project.id

  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "servicenetworking.googleapis.com",
    "storage.googleapis.com",
  ])

  service = each.key
}

// Owner access for admins 
resource "google_project_iam_member" "admins" {
  project = google_project.project.id
  role    = "roles/owner"
  member  = "group:k8s-infra-observability-admins@kubernetes.io"
}

// Viewer access
resource "google_project_iam_member" "viewers" {
  project = google_project.project.id
  role    = "roles/viewer"
  member  = "group:k8s-infra-observability-viewers@kubernetes.io"
}
