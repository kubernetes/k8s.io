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


module "cdn" {
  source = "../cdn"
  domain = "dl.k8s.dev"
  datadog_config = {
    token        = data.google_secret_manager_secret_version_access.datadog_api_key.secret_data,
    service_name = "dl.k8s.dev",
    env          = "staging",
  }
  bucket_name    = "5d7373bbdcb8270361b96548387bf2a9ad0d48758c35"
  region         = "us-central1"
  gcs_access_key = data.google_secret_manager_secret_version_access.gcs_reader_access_key.secret_data
  gcs_secret_key = data.google_secret_manager_secret_version_access.gcs_reader_secret_key.secret_data
}
