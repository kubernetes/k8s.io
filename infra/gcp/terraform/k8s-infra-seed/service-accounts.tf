resource "google_service_account" "atlantis" {
  account_id   = "atlantis"
  display_name = "Atlantis"
  project      = var.seed_project_id
}

resource "google_service_account_iam_binding" "atlantis" {
  service_account_id = google_service_account.atlantis.id

  role = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:k8s-infra-prow.svc.id.goog[atlantis/atlantis]",
  ]
}

resource "google_service_account" "datadog" {
  account_id = "datadog"
  project    = var.seed_project_id
}

resource "google_service_account_iam_binding" "datadog" {
  service_account_id = google_service_account.datadog.id
  role               = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:ddgci-3aada836c27bc3f0fb00@datadog-gci-sts-us5-prod.iam.gserviceaccount.com",
    "serviceAccount:service-127754664067@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com"
  ]
}
