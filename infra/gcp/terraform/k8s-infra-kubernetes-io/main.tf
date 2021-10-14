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

data "google_billing_account" "account" {
  billing_account = "018801-93540E-22A20E"
}

data "google_organization" "org" {
  domain = "kubernetes.io"
}

resource "google_project" "project" {
  name            = "k8s-infra-kubernetes-io"
  project_id      = "k8s-infra-kubernetes-io"
  org_id          = data.google_organization.org.org_id
  billing_account = data.google_billing_account.account.billing_account
}

resource "google_project_service" "project" {
  project = google_project.project.id
  for_each = toset([
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "monitoring.googleapis.com",
    "serviceusage.googleapis.com",
  ])
  service = each.value
}

// Ensure ONLY k8s-infra-gcp-org-admins@kubernetes.io has owner access
// to this project
resource "google_project_iam_binding" "owner" {
  project = google_project.project.id
  role    = "roles/owner"
  members = [
    "group:k8s-infra-gcp-org-admins@kubernetes.io"
  ]
}

data "google_project" "kubernetes_public" {
  project_id = "kubernetes-public"
}

resource "google_resource_manager_lien" "kubernetes_public" {
  parent = "projects/${data.google_project.kubernetes_public.number}"
  restrictions = ["resourcemanager.projects.delete"]
  origin = "do-not-delete-kubernetes-public"
  reason = "kubernetes-public hosts public-facing kubernetes project infrastructure"
}
