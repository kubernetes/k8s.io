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

//Service used by Kubernetes Service Account kettle in namespace kettle
module "aaa_kettle_sa" {
  source            = "../modules/workload-identity-service-account"
  project_id        = "kubernetes-public"
  name              = "kettle"
  description       = "default service account for pods in ${local.cluster_name}"
  cluster_namespace = "kettle"
}

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
  // Ensure prow on-call team have admin privileges
  binding {
    members = [
      "group:${local.prow_owners}",
    ]
    role = "roles/bigquery.dataOwner"
  }
  // Ensure service accounts can create/update/get/delete dataset's table
  binding {
    members = [
      "serviceAccount:${module.aaa_kettle_sa.email}",
      "serviceAccount:${google_service_account.bq_kettle_data_transfer_writer.email}"
    ]
    role = "roles/bigquery.user"
  }
}

// grant bigquery jobUser role to the service account
// so the job transfer can launch BigQuery jobs
resource "google_project_iam_member" "kettle_jobuser_binding" {
  project = data.google_project.project.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${module.aaa_kettle_sa.email}"
}

resource "google_bigquery_dataset_iam_policy" "prod_kettle_dataset" {
  dataset_id  = google_bigquery_dataset.prod_kettle_dataset.dataset_id
  project     = google_bigquery_dataset.prod_kettle_dataset.project
  policy_data = data.google_iam_policy.prod_kettle_dataset_iam_policy.policy_data
}

# Used to monitor kubernetes jenkings changes
resource "google_pubsub_topic" "notification_topic" {
  project = data.google_project.project.project_id
  name    = "k8s-infra-kubernetes-jenkins-changes"
}

# Use by kettle to collect job information
resource "google_pubsub_subscription" "kettle_subscription" {
  name    = "k8s-infra-kettle-staging"
  topic   = google_pubsub_topic.notification_topic.name
  project = data.google_project.project.project_id

  filter = "attributes.eventType = \"OBJECT_FINALIZE\""
}

resource "google_pubsub_subscription_iam_binding" "subscription_binding" {
  project      = data.google_project.project.project_id
  subscription = google_pubsub_subscription.kettle_subscription.name
  role         = "roles/pubsub.editor"
  members = [
    "serviceAccount:${module.aaa_kettle_sa.email}"
  ]
}
