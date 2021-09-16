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

/*
This file defines:
- A BigQuery dataset for prod-readiness reporting
- IAM bindings on that dataset
*/

locals {
  prod_readiness_owners = "k8s-infra-prod-readiness@kubernetes.io"
}

// BigQuery dataset for PRR analysis
resource "google_bigquery_dataset" "prod_readiness_dataset" {
  dataset_id  = "k8s_prod_readiness"
  project     = data.google_project.project.project_id
  description = "Dataset for prod-readiness approvers to use for reporting purposes"
  location    = "US"

  // Data is precious, make it difficult to delete by accident
  delete_contents_on_destroy = false
}

data "google_iam_policy" "prod_readiness_dataset_iam_policy" {
  binding {
    members = [
      "group:${local.prod_readiness_owners}",
    ]
    role = "roles/bigquery.dataOwner"
  }
}

resource "google_bigquery_dataset_iam_policy" "prod_readiness_dataset" {
  dataset_id  = google_bigquery_dataset.prod_readiness_dataset.dataset_id
  project     = google_bigquery_dataset.prod_readiness_dataset.project
  policy_data = data.google_iam_policy.prod_readiness_dataset_iam_policy.policy_data
}

// This is intended solely for queries against k8s_prod_readiness but since
// we can't apply this role at the dataset level, we need to grant the ability
// to run jobs against any dataset in this project.
resource "google_project_iam_member" "prod_readiness_job_user" {
  project = google_bigquery_dataset.prod_readiness_dataset.project
  role    = "roles/bigquery.jobUser"
  member  = "group:${local.prod_readiness_owners}"
}
