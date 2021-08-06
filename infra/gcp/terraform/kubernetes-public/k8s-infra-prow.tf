/*
This file defines:
- a bucket for k8s-infra-prow
- a GCP service account for the bucket
- IAM bindings for the bucket
- a Secret Manager secret for the service account key
*/

locals {
  bucket_name               = "k8s-infra-prow-results"
  bucket_location           = "us-central1"
  prow_service_account      = "k8s-infra-prow"
  test_pods_namespace       = "k8s-infra-prow-pods"
  test_pods_service_account = "default"
}


// Create GCP Service Account for prow control plane
resource "google_service_account" "k8s_infra_prow" {
  project      = data.google_project.project.project_id
  account_id   = local.prow_service_account
  display_name = local.prow_service_account
}

// Create a key for GCP Service Account k8s-infra-prow
resource "google_service_account_key" "k8s_infra_prow" {
  service_account_id = google_service_account.k8s_infra_prow.name
  private_key_type   = "TYPE_GOOGLE_CREDENTIALS_FILE"
}

// Allow pods using the build cluster KSA to use the GCP SA k8s-infra-prow via workload identity
resource "google_service_account_iam_member" "prow_build_cluster_sa_iam" {
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.k8s_infra_prow.name
  member             = format("serviceAccount:%s.svc.id.goog[%s/%s]", "k8s-infra-prow-build", local.test_pods_namespace, local.test_pods_service_account)
}

// Allow pods using the build cluster KSA to use the GCP SA k8s-infra-prow via workload identity
resource "google_service_account_iam_member" "prow_build_trusted_cluster_sa_iam" {
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.k8s_infra_prow.name
  member             = format("serviceAccount:%s.svc.id.goog[%s/%s]", "k8s-infra-prow-build-trusted", local.test_pods_namespace, local.test_pods_service_account)
}

// Create a GCS bucket for ProwJobs logs and tide history
resource "google_storage_bucket" "k8s_infra_prow_bucket" {
  name          = local.bucket_name
  project       = data.google_project.project.project_id
  storage_class = "REGIONAL"
  location      = local.bucket_location

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
}

// Allow GCP SA k8s-infra-prow admin for the objects in the bucket k8s-infra-prow-results
resource "google_storage_bucket_iam_member" "k8s_infra_prow_admin" {
  bucket = google_storage_bucket.k8s_infra_prow_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.k8s_infra_prow.email}"
}

// Allow GCP SA k8s-infra-prow admin (legacy role) for the objects in the bucket k8s-infra-prow-results
resource "google_storage_bucket_iam_member" "k8s_infra_prow_admin_legacy" {
  bucket = google_storage_bucket.k8s_infra_prow_bucket.name
  role   = "roles/storage.legacyBucketWriter"
  member = "serviceAccount:${google_service_account.k8s_infra_prow.email}"
}

// Allow read access to members of k8s-infra-prow-oncall@kubernetes.io
resource "google_storage_bucket_iam_member" "k8s_infra_prow_oncall" {
  bucket = google_storage_bucket.k8s_infra_prow_bucket.name
  role   = "roles/storage.objectViewer"
  //TODO(ameukam): switch to allUsers when https://github.com/kubernetes/k8s.io/issues/752 is closed.
  member = "group:k8s-infra-prow-oncall@kubernetes.io"
}

// Create a secret for GCP Service Account key of k8s-infra-prow
resource "google_secret_manager_secret" "k8s_infra_prow_key" {
  project   = data.google_project.project.project_id
  secret_id = "${local.prow_service_account}-sa-key"

  replication {
    automatic = true
  }
}

// Create a version for the GCP Secret Manager secret 
resource "google_secret_manager_secret_version" "k8s_infra_prow_key_version" {
  secret      = google_secret_manager_secret.k8s_infra_prow_key.id
  secret_data = base64decode(google_service_account_key.k8s_infra_prow.private_key)
}

// Allow read access to members of k8s-infra-prow-oncall@kubernetes.io
resource "google_secret_manager_secret_iam_binding" "name" {
  project   = data.google_project.project.project_id
  secret_id = google_secret_manager_secret.k8s_infra_prow_key.id
  role      = "roles/secretmanager.admin"
  members = [
    "group:k8s-infra-prow-oncall@kubernetes.io"
  ]
}

