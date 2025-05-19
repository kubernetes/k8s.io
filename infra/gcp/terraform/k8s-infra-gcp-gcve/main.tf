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

locals {
  project_id = "broadcom-451918"
}

data "google_project" "project" {
  project_id      = local.project_id
}

resource "google_project_service" "project" {
  project = data.google_project.project.id

  for_each = toset([
    "compute.googleapis.com",
    "secretmanager.googleapis.com",
    "vmwareengine.googleapis.com"
  ])

  service = each.key
}

// Ensure sig-k8s-infra-leads@kubernetes.io has admin access to this project
resource "google_project_iam_member" "k8s_infra_leads" {
  project = data.google_project.project.id
  role    = "roles/admin"
  member  = "group:sig-k8s-infra-leads@kubernetes.io"
}

# TODO(chrischdi): we first need the group
# // Ensure k8s-infra-vsphere@kubernetes.io has owner access to this project
# resource "google_project_iam_member" "k8s_infra_vsphere" {
#   project = data.google_project.project.id
#   role    = "roles/owner"
#   member  = "group:k8s-infra-vsphere@kubernetes.io"
# }
