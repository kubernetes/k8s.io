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

/*
Ensure audit logging is enabled for GCS.
See: https://cloud.google.com/storage/docs/audit-logging
*/
module "audit_log_config" {
  source  = "terraform-google-modules/iam/google//modules/audit_config"
  version = "~> 8.1"

  project = module.project.project_id

  audit_log_config = [
    {
      service          = "storage.googleapis.com"
      log_type         = "DATA_READ"
      exempted_members = []
    }
  ]
}

module "iam" {
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 8"

  projects = [module.project.project_id]

  mode = "authoritative"

  bindings = {
    "roles/viewer" = [
      "group:k8s-infra-release-editors@kubernetes.io",
    ]
  }
}
