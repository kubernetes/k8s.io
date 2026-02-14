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

module "iam" {
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 8.2"

  projects = [module.project.project_id]

  mode = "authoritative"

  bindings = {
    "roles/artifactregistry.admin" = [
      "group:k8s-infra-artifact-admins@kubernetes.io",
    ]
    "roles/artifactregistry.repoAdmin" = [
      "serviceAccount:k8s-infra-gcr-promoter@k8s-artifacts-prod.iam.gserviceaccount.com"
    ]
    "roles/errorreporting.user" = [
      "group:k8s-infra-artifact-admins@kubernetes.io",
    ]
    "roles/serviceusage.serviceUsageConsumer" = [
      "group:k8s-infra-artifact-admins@kubernetes.io",
    ]
    "roles/viewer" = [
      "group:k8s-infra-artifact-admins@kubernetes.io",
      "group:k8s-infra-artifact-security@kubernetes.io",
    ]
  }
}

module "audit_logs" {
  source  = "terraform-google-modules/iam/google//modules/audit_config"
  version = "~> 8.2"

  project = module.project.project_id
  audit_log_config = [
    {
      service          = "artifactregistry.googleapis.com"
      log_type         = "DATA_READ"
      exempted_members = null
    },
    {
      service          = "artifactregistry.googleapis.com"
      log_type         = "DATA_WRITE"
      exempted_members = null
    },
  ]
}
