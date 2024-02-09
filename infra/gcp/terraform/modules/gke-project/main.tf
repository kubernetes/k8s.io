/*
Copyright 2020 The Kubernetes Authors.

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

// hardcoded org and billing account, not sure we want this
// reusable outside of k8s-infra
locals {
  org_domain      = "kubernetes.io"
  billing_account = "018801-93540E-22A20E"

  project_services = [
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "oslogin.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "stackdriver.googleapis.com",
    "storage-component.googleapis.com",
  ]


  cluster_admins_group_iam = [
    "roles/compute.viewer",
    "roles/container.admin",
    data.google_iam_role.service_account_lister.name,
  ]

  cluster_users_group_iam = [
    "roles/container.clusterViewer"
  ]
}

data "google_organization" "org" {
  domain = local.org_domain
}

// TODO(spiffxp): explicitly not using a data source for this until
// I have a better sense of whether this requires more permissions
// than (are / should be) available for k8s-infra-prow-oncall and
// k8s-infra-cluster-admins
// data google_billing_account {
// billing_account = locals.billing_account
// }

// Create the project in which we're creating the cluster
resource "google_project" "project" {
  name            = var.project_name
  project_id      = var.project_name
  org_id          = data.google_organization.org.org_id
  billing_account = local.billing_account
}

// Services we need
resource "google_project_service" "services" {
  for_each                   = toset(local.project_services)
  project                    = google_project.project.project_id
  service                    = each.value
  disable_dependent_services = true
}

// Role created by ensure-organization.sh, use a data source to ensure it exists
data "google_iam_role" "service_account_lister" {
  name = "${data.google_organization.org.name}/roles/iam.serviceAccountLister"
}

// "Empower cluster admins" is what ensure-main-project.sh says
resource "google_project_iam_member" "cluster_admins" {
  for_each = toset(local.cluster_admins_group_iam)
  project  = google_project.project.project_id
  role     = each.value
  member   = "group:${var.cluster_admins_group}"
}

// "Empowering cluster users" is what ensure-main-project.sh says
resource "google_project_iam_member" "cluster_users" {
  for_each = toset(local.cluster_users_group_iam)
  project  = google_project.project.project_id
  role     = each.value
  member   = "group:${var.cluster_users_group}"
}
