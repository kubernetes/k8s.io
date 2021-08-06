
// Service account dedicated for BigQuery Data Transfer
resource "google_service_account" "bq_data_transfer_writer" {
  account_id  = "bq-data-transfer"
  description = "Service Acccount BigQuery Data Transfer"
  project     = google_project.project.project_id
}

// grant bigquery dataEditor role to the service account so that scheduled query can run
resource "google_project_iam_member" "bq_data_transfer_writer_binding" {
  project = google_project.project.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.bq_data_transfer_writer.email}"
}

resource "google_bigquery_data_transfer_config" "bq_data_transfer" {
  display_name           = "BigQuey data transfer to ${google_bigquery_dataset.audit-logs-gcs.dataset_id}"
  project                = google_project.project.project_id
  data_source_id         = "cross_region_copy"
  schedule               = "every 24 hours" #Times are in UTC
  destination_dataset_id = google_bigquery_dataset.audit-logs-gcs.dataset_id
  service_account_name   = google_service_account.bq_data_transfer_writer.email
  disabled               = false

  params = {
    overwrite_destination_table = "true"
    source_dataset_id           = "riaan_data_store"
    source_project_id           = "k8s-infra-ii-sandbox"
  }

  schedule_options {
    disable_auto_scheduling = false
    start_time              = "2021-07-29T15:00:00Z"
  }

  email_preferences {
    enable_failure_email = true
  }
}
