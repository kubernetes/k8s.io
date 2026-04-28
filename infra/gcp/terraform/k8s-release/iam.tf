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

  projects = [module.project.project_id]

  mode = "authoritative"

  bindings = {
    "roles/cloudbuild.builds.editor" = [
      "group:k8s-infra-release-editors@kubernetes.io",
    ]
    "roles/cloudbuild.workerPoolUser" = [
      "group:k8s-infra-release-editors@kubernetes.io",
    ]
    "roles/owner" = [
      "group:k8s-infra-release-admins@kubernetes.io",
    ]
    "roles/storage.admin" = [
      "group:k8s-infra-release-editors@kubernetes.io",
    ]
    "roles/secretmanager.secretAccessor" = [
      "serviceAccount:304687256732@cloudbuild.gserviceaccount.com"
    ]
    "roles/viewer" = [
      "group:k8s-infra-release-viewers@kubernetes.io",
      "group:k8s-infra-release-editors@kubernetes.io",
    ]
    "roles/serviceusage.serviceUsageConsumer" = [
      "group:k8s-infra-release-editors@kubernetes.io",
    ]
  }
}
