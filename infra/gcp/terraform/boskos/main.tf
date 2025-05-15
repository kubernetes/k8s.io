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

resource "google_folder" "boskos" {
  display_name = "Boskos"
  parent       = "organizations/758905017065"
}

locals {
  boskos_e2e_projects = [
    for i in range("001", "160") : format("k8s-infra-e2e-boskos-%03d", i)
  ]
  boskos_scale_e2e_projects = [
    for i in range("001", "30") : format("k8s-infra-e2e-boskos-scale-%02d", i)
  ]
  boskos_projects = concat(
    local.boskos_e2e_projects,
    local.boskos_scale_e2e_projects,
  )
}

module "project" {
  for_each = toset(local.boskos_projects)
  source   = "terraform-google-modules/project-factory/google"
  version  = "~> 18.0"

  name            = each.key
  project_id      = each.key
  folder_id       = google_folder.boskos.id
  org_id          = "758905017065"
  billing_account = "018801-93540E-22A20E"

  # Sane project defaults
  default_service_account     = "keep"
  disable_services_on_destroy = false
  create_project_sa           = false
  random_project_id           = false

  activate_apis = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "file.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
  ]
}

resource "google_compute_project_metadata" "default" {
  for_each = toset(local.boskos_projects)
  project  = module.project[each.key].project_id
  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = <<EOF
prow:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCmYxHh/wwcV0P1aChuFLpl28w6DFyc7G5Xrw1F8wH1Re9AdxyemM2bTZ/PhsP3u9VDnNbyOw3UN00VFdumkFLjLf1WQ7Q6rZDlPjlw7urBIvAMqUecY6ae1znqsZ0dMBxOuPXHznlnjLjM5b7O7q5WsQMCA9Szbmz6DsuSyCuX0It2osBTN+8P/Fa6BNh3W8AF60M7L8/aUzLfbXVS2LIQKAHHD8CWqvXhLPuTJ03iSwFvgtAK1/J2XJwUP+OzAFrxj6A9LW5ZZgk3R3kRKr0xT/L7hga41rB1qy8Uz+Xr/PTVMNGW+nmU4bPgFchCK0JBK7B12ZcdVVFUEdpaAiKZ prow"
prow:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+/ZdafYYrJknk08g98sYS1Nr+aVdAnhHpQyXBx7EAT9pazCGaoiYnXgC82FAfTVMqdsqnIiP+7FgQTFLNYvBt8KsBd9qCkuMh/Q1QYVh4kfjjuGUrjfo020pxGSvp+67kbxm6lubaio9AgJ9XXE+SP1AYbyKTvXEzk5Tu7gGnRt3OrjVB+9eqTnVJOjS/BAOTJV5DWQ7xMubHlT9NmQ/S2hotMoiJJybYGUalOfcf8ZkyspU2oR+x13DCfjvFdzF4U0fb/uvTJZeu22w887M5y0YQulFY2LIeoAUE4XwoOv0nxzwbtZpqPHwtfLgq3G906KHW5e6slXu8kGda656n prow"
EOF
  }
  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"] #  mutated by CI all the time, ignore after initial creation
    ]
  }
}

module "artifact_registry" {
  for_each = toset(local.boskos_projects)
  source   = "GoogleCloudPlatform/artifact-registry/google"
  version  = "~> 0.3"

  project_id    = module.project[each.key].project_id
  location      = "us"
  format        = "DOCKER"
  repository_id = "gcr.io"
  members = {
    readers = ["allUsers"]
  }
  cleanup_policies = {
    delete-images-older-than-7-days = {
      action = "DELETE"
      condition = {
        older_than = "604800s"
      }
    }
  }
}

import {
  for_each = toset(local.boskos_projects)
  to       = module.project[each.key].module.project-factory.google_project.main
  id       = each.value
}

import {
  for_each = toset(local.boskos_projects)
  to       = google_compute_project_metadata.default[each.key]
  id       = each.value
}
