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

module "iam" {
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 8.1"

  projects = [var.project_id]

  mode = "authoritative"

  bindings = {
    "roles/admin" = [
      "group:sig-k8s-infra-leads@kubernetes.io",
      "group:k8s-infra-gcp-gcve-admins@kubernetes.io",
      "serviceAccount:atlantis@k8s-infra-seed.iam.gserviceaccount.com",
    ]
    "roles/secretmanager.secretAccessor" = [
      "serviceAccount:k8s-infra-prow-build.svc.id.goog[external-secrets/external-secrets]"
    ]
    "roles/viewer" = [
      "serviceAccount:datadog@k8s-infra-seed.iam.gserviceaccount.com"
    ]
    "roles/serviceusage.serviceUsageConsumer" = [
      "serviceAccount:datadog@k8s-infra-seed.iam.gserviceaccount.com"
    ]
  }
}
