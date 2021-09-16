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
- A BigQuery dataset for kettle tests results
- IAM bindings on that dataset
*/

// BigQuery dataset for Kettle
resource "google_bigquery_dataset" "prod_kettle_dataset" {
  dataset_id  = "k8s_infra_kettle"
  project     = data.google_project.project.project_id
  description = "Dataset for Kubernetes tests results"
  location    = "US"

  // Data is precious, make it difficult to delete by accident
  delete_contents_on_destroy = false
}

data "google_iam_policy" "prod_kettle_dataset_iam_policy" {
  binding {
    members = [
      "group:k8s-infra-prow-oncall@kubernetes.io",
    ]
    role = "roles/bigquery.dataOwner"
  }
}

resource "google_bigquery_dataset_iam_policy" "prod_kettle_dataset" {
  dataset_id  = google_bigquery_dataset.prod_kettle_dataset.dataset_id
  project = google_bigquery_dataset.prod_kettle_dataset.project
  policy_data = data.google_iam_policy.prod_kettle_dataset_iam_policy.policy_data
}


