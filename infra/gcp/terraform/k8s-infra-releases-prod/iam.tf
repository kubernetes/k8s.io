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

data "google_iam_policy" "releng_access" {
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "group:k8s-infra-release-editors@kubernetes.io",
      "serviceAccount:${google_service_account.fastly_reader.email}"
    ]
  }

  // TODO: remove this after https://github.com/kubernetes/release/issues/3425
  binding {
    role    = "roles/storage.objectAdmin"
    members = ["serviceAccount:648026197307@cloudbuild.gserviceaccount.com"]
  }

  binding {
    role = "roles/storage.legacyBucketOwner"
    members = [
      "projectOwner:${google_project.project.project_id}",
      "projectEditor:${google_project.project.project_id}"
    ]
  }

  binding {
    role = "roles/storage.legacyBucketReader"
    members = [
      "projectViewer:${google_project.project.project_id}",
      "group:k8s-infra-release-editors@kubernetes.io"
    ]
  }
}

resource "google_storage_bucket_iam_policy" "releng_access_policy" {
  bucket      = module.k8s_releases_prod.bucket_name
  policy_data = data.google_iam_policy.releng_access.policy_data
}

/*
Ensure audit logging is enabled for GCS.
See: https://cloud.google.com/storage/docs/audit-logging
*/
module "audit_log_config" {
  source  = "terraform-google-modules/iam/google//modules/audit_config"
  version = "~> 8.1"

  project = google_project.project.project_id

  audit_log_config = [
    {
      service          = "storage.googleapis.com"
      log_type         = "DATA_READ"
      exempted_members = []
    }
  ]
}
