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

resource "google_service_account" "atlantis" {
  account_id   = "atlantis"
  display_name = "Atlantis"
  project      = var.seed_project_id
}

resource "google_service_account_iam_binding" "atlantis" {
  service_account_id = google_service_account.atlantis.id

  role = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:k8s-infra-prow.svc.id.goog[atlantis/atlantis]",
  ]
}

resource "google_service_account" "datadog" {
  account_id = "datadog"
  project    = var.seed_project_id
}

resource "google_service_account_iam_binding" "datadog" {
  service_account_id = google_service_account.datadog.id
  role               = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:ddgci-3aada836c27bc3f0fb00@datadog-gci-sts-us5-prod.iam.gserviceaccount.com",
    "serviceAccount:service-127754664067@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com",
    "serviceAccount:service-305468410906@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com"
  ]
}
