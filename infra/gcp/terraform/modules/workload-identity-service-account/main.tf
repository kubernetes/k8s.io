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

// creates a service account in project_id with name and description
// usable by pods in cluster_project_id
// running in namespace cluster_namespace
// running as cluster_serviceaccount_name

locals {
  description                 = var.description != "" ? var.description : var.name
  cluster_project_id          = var.cluster_project_id != "" ? var.cluster_project_id : var.project_id
  cluster_serviceaccount_name = var.cluster_serviceaccount_name != "" ? var.cluster_serviceaccount_name : var.name
}

resource "google_service_account" "serviceaccount" {
  project      = var.project_id
  account_id   = var.name
  display_name = local.description
}
data "google_iam_policy" "workload_identity" {
  binding {
    members = concat(["serviceAccount:${local.cluster_project_id}.svc.id.goog[${var.cluster_namespace}/${local.cluster_serviceaccount_name}]"],
      var.additional_workload_identity_principals
    )

    role = "roles/iam.workloadIdentityUser"
  }
}
// authoritative binding, replaces any existing IAM policy on the service account
resource "google_service_account_iam_policy" "serviceaccount_iam" {
  service_account_id = google_service_account.serviceaccount.name
  policy_data        = data.google_iam_policy.workload_identity.policy_data
}
// optional: roles to grant the serviceaccount on the project
resource "google_project_iam_member" "project_roles" {
  for_each = toset(var.project_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.serviceaccount.email}"
}
