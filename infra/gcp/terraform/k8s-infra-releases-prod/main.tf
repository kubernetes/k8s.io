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

locals {
  billing_account = "018801-93540E-22A20E"
  org_id          = "758905017065"
  project_id      = "k8s-infra-releases-prod"
}


resource "google_project" "project" {
  name                = local.project_id
  project_id          = local.project_id
  org_id              = local.org_id
  billing_account     = local.billing_account
  auto_create_network = false
}

module "k8s_releases_prod" {
  source      = "../modules/k8s-releases"
  project_id  = google_project.project.project_id
  bucket_name = "767373bbdcb8270361b96548387bf2a9ad0d48758c35"
}

resource "google_service_account" "fastly_reader" {
  project     = google_project.project.project_id
  account_id  = "fastly-reader"
  description = "Used by Fastly for read-only actions against the bucket"
}

resource "google_storage_hmac_key" "fastly_reader_key" {
  project               = google_project.project.project_id
  service_account_email = google_service_account.fastly_reader.email
}

