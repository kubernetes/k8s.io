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

// The 5k scale projects require a service account that can pull from a dedicated AR registry in the 5k project
// However, the account must be created in the prow-build project to avoid boskos deleting the keys and the account on cleanup.
// Service Accounts don't supports labels yet, if it did we could tell boskos to skip the account based on the labels

resource "google_service_account" "scale_cache" {
  account_id   = "scale-cache-puller"
  display_name = "Scale Test Cache Puller"
  project      = module.project.project_id
}

resource "google_service_account_key" "scale_cache" {
  service_account_id = google_service_account.scale_cache.id
}

resource "google_secret_manager_secret" "scale_cache_key" {
  project   = module.project.project_id
  secret_id = "scale-cache-puller-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "scale_cache_key" {
  secret      = google_secret_manager_secret.scale_cache_key.id
  secret_data = "Basic ${base64encode("_json_key_base64:${google_service_account_key.scale_cache.private_key}")}"
}
