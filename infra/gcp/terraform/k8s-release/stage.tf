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
// with a fixed config uses. Mock stages, which may build forks, run as
// another account. It can't write the production bucket or registry, read
// the production secrets or sign as the staging signer. Release admins, who
// own this project, stay trusted. Release managers request stages and reruns
// of the signing build through topics. The triggers follow with their
// configs.
resource "google_service_account" "krel_stage" {
  project      = module.project.project_id
  account_id   = "krel-stage"
  display_name = "Kubernetes release stage"
}

resource "google_service_account" "krel_stage_mock" {
  project      = module.project.project_id
  account_id   = "krel-stage-mock"
  display_name = "Kubernetes mock release stage"
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

locals {
  stage_accounts = {
    stage      = google_service_account.krel_stage.member
    mock_stage = google_service_account.krel_stage_mock.member
  }
}

// The stage builds log to Cloud Logging. These are members and not in the
// authoritative module in iam.tf, whose bindings would all become unknown
// with a member of an account created in the same plan.
resource "google_project_iam_member" "stage_log_writer" {
  for_each = local.stage_accounts

  project = module.project.project_id
  role    = "roles/logging.logWriter"
  member  = each.value
}

// Production stages read the GitHub and Docker Hub tokens and the OBS
// password, and no other secret of the project. Mock stages get their own
// secrets with the stage trigger, since they can run code from forks.
resource "google_secret_manager_secret_iam_member" "krel_stage" {
  for_each = toset(["github-token", "dockerhub-token", "obs-password"])

  project   = module.project.project_id
  secret_id = each.key
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.krel_stage.member
}

// Mock stages write the stage directory of the mock bucket only, and list
// and read it through the public read access of the bucket. The bucket module
// doesn't support IAM conditions, so this binding lives outside of it.
resource "google_storage_bucket_iam_member" "mock_krel_stage" {
  bucket = module.mock_bucket.name
  role   = "roles/storage.objectUser"
  member = google_service_account.krel_stage_mock.member

  condition {
    title      = "stage"
    expression = "resource.name.startsWith(\"projects/_/buckets/${module.mock_bucket.name}/objects/stage/\")"
  }
}
