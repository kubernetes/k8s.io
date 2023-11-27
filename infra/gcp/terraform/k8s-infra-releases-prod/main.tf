/*
Copyright 2023 The Kubernetes Authors.

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

locals {
  billing_account = "018801-93540E-22A20E"
  org_id          = "758905017065"
  project_id      = "k8s-infra-releases-prod"
}

data "google_storage_transfer_project_service_account" "default" {
  project = google_project.project.project_id
}

resource "google_project" "project" {
  name                = local.project_id
  project_id          = local.project_id
  org_id              = local.org_id
  billing_account     = local.billing_account
  auto_create_network = false
}

module "k8s_releases_prod" {
  source                   = "../modules/k8s-releases"
  project_id               = google_project.project.project_id
  bucket_name              = "767373bbdcb8270361b96548387bf2a9ad0d48758c35"
}

resource "google_service_account" "fastly_reader" {
  project = google_project.project.project_id
  account_id = "fastly-reader"
  description = "Used by Fastly for read-only actions against the bucket"
}

resource "google_storage_hmac_key" "fastly_reader_key" {
  project = google_project.project.project_id
  service_account_email = google_service_account.fastly_reader.email
}

resource "google_storage_bucket_iam_member" "fastly_reader" {
  bucket     = module.k8s_releases_prod.bucket_name
  role = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.fastly_reader.email}"
  depends_on = [module.k8s_releases_prod]
}

resource "google_storage_bucket_iam_member" "gcs-backup-bucket" {
  bucket     = module.k8s_releases_prod.bucket_name
  role       = "roles/storage.admin"
  member     = "serviceAccount:${data.google_storage_transfer_project_service_account.default.email}"
  depends_on = [module.k8s_releases_prod]
}

resource "google_pubsub_topic" "topic" {
  project = google_project.project.project_id
  name    = var.pubsub_topic_name
}

resource "google_pubsub_topic_iam_member" "notification_config" {
  project = google_project.project.project_id
  topic   = google_pubsub_topic.topic.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_transfer_project_service_account.default.email}"
}

resource "google_storage_transfer_job" "kubernetes_release_backup" {
  description = "Daily backup of GCS bucket gs://kubernetes-release"
  project     = google_project.project.project_id

  transfer_spec {
    object_conditions {
      max_time_elapsed_since_last_modification = "600s"
    }

    transfer_options {
      delete_objects_unique_in_sink = false
    }

    gcs_data_source {
      bucket_name = "kubernetes-release"
      path        = "release/"
    }

    gcs_data_sink {
      bucket_name = module.k8s_releases_prod.bucket_name
      path        = "release/"
    }
  }

  schedule {
    schedule_start_date {
      year  = 2023
      month = 10
      day   = 30
    }
    start_time_of_day {
      hours   = 17
      minutes = 33
      seconds = 0
      nanos   = 0
    }
    repeat_interval = "86400s" # 1 day
  }

  notification_config {
    pubsub_topic = google_pubsub_topic.topic.id
    event_types = [
      "TRANSFER_OPERATION_SUCCESS",
      "TRANSFER_OPERATION_FAILED"
    ]
    payload_format = "JSON"
  }

  depends_on = [module.k8s_releases_prod, google_pubsub_topic_iam_member.notification_config]
}
