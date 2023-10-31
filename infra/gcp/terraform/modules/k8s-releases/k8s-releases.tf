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


// Enable required services for this module
resource "google_project_service" "service" {
  for_each = toset([
    "storage.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storageinsights.googleapis.com",
    "storagetransfer.googleapis.com",
  ])

  project = var.project_id
  service = each.key

  disable_on_destroy = false
}

resource "google_storage_bucket" "k8s_releases" {
  name     = var.bucket_name
  location = var.region
  project  = var.project_id

  storage_class               = var.storage_class
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  public_access_prevention = var.public_access_prevention

  lifecycle {
    prevent_destroy = true
  }
}
