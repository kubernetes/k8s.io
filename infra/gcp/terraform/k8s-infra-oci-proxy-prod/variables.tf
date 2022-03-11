/*
Copyright 2022 The Kubernetes Authors.

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

variable "tag" {
  type    = string
  default = "latest"
}

variable "cloud_run_regions" {
  type = list(string)
  default = [
    # Tier 1 pricing: https://cloud.google.com/run/pricing#tables
    "asia-east1",
    "asia-northeast1",
    "europe-north1",
    "europe-west1",
    "europe-west4",
    "us-central1",
    "us-east1",
    "us-east4"
  ]
}
