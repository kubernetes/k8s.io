/*
Copyright 2026 The Kubernetes Authors.

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

module "iam" {
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 8"

  projects = ["k8s-infra-oci-proxy"]

  mode = "authoritative"

  bindings = {
    "roles/storage.objectAdmin" = [
      "serviceAccount:infra-tools-sa@k8s-staging-images.iam.gserviceaccount.com"
    ],
    "roles/run.admin" = [
      "serviceAccount:infra-tools-sa@k8s-staging-images.iam.gserviceaccount.com"
    ],
    "roles/viewer" = [
      "serviceAccount:infra-tools-sa@k8s-staging-images.iam.gserviceaccount.com"
    ]
  }
}
