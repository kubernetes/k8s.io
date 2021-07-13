
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

resource "google_project" "project" {
  name       = local.project_id
  project_id = local.project_id
}

#Create service account
resource "google_service_account" "ii-logs-sa@k8s-infra-ii-sandbox.iam.gserviceaccount.com" {
  account_id   = "ii-logs-sa-id"
  display_name = "ii logs service account"
  description  = "service-account-to-facilitate-ii-log-analysis"
  project      = google_project.project.id
}

resource "google_project_iam_binding" "k8s-infra-ii-sandbox" {
  project = google_project.project.id
  role    = "roles/storage.objectViewer"
  members = [
    "user:ii-logs-sa@k8s-infra-ii-sandbox.iam.gserviceaccount.com",
  ]
}
