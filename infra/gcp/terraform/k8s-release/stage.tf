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

// Level 3: the stage runs as its own account, which only the stage trigger
// with a fixed config uses. Once level 1 is retired and the k8s-release Cloud
// Build account can no longer write the stage directory, no other build can
// write it while a stage runs; release admins, who own this project, stay
// trusted. Release managers request stages and reruns of the signing build
// through topics. The triggers and the permissions of the account follow
// with them.
resource "google_service_account" "krel_stage" {
  project      = module.project.project_id
  account_id   = "krel-stage"
  display_name = "Kubernetes release stage"
}

resource "google_pubsub_topic" "stage_requests" {
  project = module.project.project_id
  name    = "krel-stage-requests"
}

resource "google_pubsub_topic" "provenance_reruns" {
  project = module.project.project_id
  name    = "krel-provenance-reruns"
}

resource "google_pubsub_topic_iam_member" "stage_requests_publisher" {
  project = module.project.project_id
  topic   = google_pubsub_topic.stage_requests.name
  role    = "roles/pubsub.publisher"
  member  = "group:k8s-infra-release-editors@kubernetes.io"
}

resource "google_pubsub_topic_iam_member" "provenance_reruns_publisher" {
  project = module.project.project_id
  topic   = google_pubsub_topic.provenance_reruns.name
  role    = "roles/pubsub.publisher"
  member  = "group:k8s-infra-release-editors@kubernetes.io"
}
