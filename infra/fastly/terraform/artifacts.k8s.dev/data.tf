/*
Copyright 2024 The Kubernetes Authors.

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

data "google_secret_manager_secret_version_access" "datadog_api_key" {
  secret  = "datadog_fastly_logs_streaming"
  project = "k8s-infra-releases-prod"
}

data "google_secret_manager_secret_version_access" "gcs_reader_access_key" {
  secret  = "fastly_reader_sa_access_key"
  project = "k8s-infra-releases-prod"
}

data "google_secret_manager_secret_version_access" "gcs_reader_secret_key" {
  secret  = "fastly_reader_sa_secret_key"
  project = "k8s-infra-releases-prod"
}

data "google_secret_manager_secret_version_access" "fastly_api_key" {
  secret  = "fastly-api-key"
  project = "k8s-infra-prow"
}
