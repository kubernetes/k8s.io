/*
This file defines:
- GCP Service Account for nodes
- Bigquery dataset for usage metering
- GKE cluster configuration

Note that it does not configure any node pools; this is done in a separate file.
*/

locals {
  cluster_name            = "prow-build-test"     // The name of the cluster defined in this file
  cluster_ksa_name        = "prow-build"          // MUST match the name of the KSA intended to use the prow_build_cluster_sa serviceaccount
  cluster_location        = "us-central1"         // The GCP location (region or zone) where the cluster should be created
  bigquery_location       = "US"                  // The bigquery specific location where the dataset should be created
  pod_namespace           = "test-pods"           // MUST match whatever prow is configured to use when it schedules to this cluster
  boskos_janitor_gsa_name = "boskos-janitor-test" // The name of the GCP SA used by boskos-janitor
  boskos_janitor_ksa_name = "boskos-janitor"      // MUST match the name of the KSA intended to use the boskos_janitor_sa serviceaccount
}

// Create GCP SA for pods
// terraform import google_service_account.prow_build_cluster_sa projects/kubernetes-public/serviceAccounts/prow-build-test@kubernetes-public.iam.gserviceaccount.com
resource "google_service_account" "prow_build_cluster_sa" {
  project      = data.google_project.project.id
  account_id   = local.cluster_name
  display_name = "Used by pods in '${local.cluster_name}' GKE cluster"
}
// Allow pods using the build cluster KSA to use the GCP SA via workload identity
data "google_iam_policy" "prow_build_cluster_sa_workload_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "serviceAccount:${data.google_project.project.id}.svc.id.goog[${local.pod_namespace}/${local.cluster_ksa_name}]",
    ]
  }
}
// Authoritative iam-policy: replaces any existing policy attached
// terraform import google_service_account_iam_policy.prow_build_cluster_sa_iam projects/kubernetes-public/serviceAccounts/prow-build-test@kubernetes-public.iam.gserviceaccount.com
resource "google_service_account_iam_policy" "prow_build_cluster_sa_iam" {
  service_account_id = google_service_account.prow_build_cluster_sa.name
  policy_data        = data.google_iam_policy.prow_build_cluster_sa_workload_identity.policy_data
}

// Create GCP SA for boskos-janitor
// terraform import google_service_account.boskos_janitor_sa projects/kubernetes-public/serviceAccounts/boskos-janitor-test@kubernetes-public.iam.gserviceaccount.com
resource "google_service_account" "boskos_janitor_sa" {
  project      = data.google_project.project.id
  account_id   = local.boskos_janitor_gsa_name
  display_name = "Used by boskos-janitor in '${local.cluster_name}' GKE cluster"
}
// Allow pods using the build cluster KSA to use the GCP SA via workload identity
data "google_iam_policy" "boskos_janitor_sa_workload_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "serviceAccount:${data.google_project.project.id}.svc.id.goog[${local.pod_namespace}/${local.boskos_janitor_ksa_name}]",
    ]
  }
}
// Authoritative iam-policy: replaces any existing policy attached
// terraform import google_service_account_iam_policy.boskos_janitor_sa_iam projects/kubernetes-public/serviceAccounts/boskos-janitor-test@kubernetes-public.iam.gserviceaccount.com
resource "google_service_account_iam_policy" "boskos_janitor_sa_iam" {
  service_account_id = google_service_account.boskos_janitor_sa.name
  policy_data        = data.google_iam_policy.boskos_janitor_sa_workload_identity.policy_data
}

// Create GCP SA for nodes
resource "google_service_account" "cluster_node_sa" {
  project      = data.google_project.project.id
  account_id   = "gke-nodes-${local.cluster_name}"
  display_name = "Nodes in GKE cluster '${local.cluster_name}'"
}

// Add roles for SA
resource "google_project_iam_member" "cluster_node_sa_logging" {
  project = data.google_project.project.id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cluster_node_sa.email}"
}
resource "google_project_iam_member" "cluster_node_sa_monitoring_viewer" {
  project = data.google_project.project.id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.cluster_node_sa.email}"
}
resource "google_project_iam_member" "cluster_node_sa_monitoring_metricwriter" {
  project = data.google_project.project.id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cluster_node_sa.email}"
}

// BigQuery dataset for usage data
resource "google_bigquery_dataset" "usage_metering" {
  dataset_id  = replace("usage_metering_${local.cluster_name}", "-", "_")
  project     = data.google_project.project.id
  description = "GKE Usage Metering for cluster '${local.cluster_name}'"
  location    = local.bigquery_location

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }
  access {
    role          = "WRITER"
    user_by_email = google_service_account.cluster_node_sa.email
  }

  // This restricts deletion of this dataset if there is data in it
  // IMPORTANT: Should be true on test clusters
  delete_contents_on_destroy = true
}

// Create GKE cluster, but with no node pools. Node pools can be provisioned below
resource "google_container_cluster" "cluster" {
  name     = local.cluster_name
  location = local.cluster_location

  provider = google-beta
  project  = data.google_project.project.id

  // GKE clusters are critical objects and should not be destroyed
  // IMPORTANT: should be false on test clusters
  lifecycle {
    prevent_destroy = false
  }

  // Network config
  network = "default"

  // Start with a single node, because we're going to delete the default pool
  initial_node_count = 1

  // Removes the default node pool, so we can custom create them as separate
  // objects
  remove_default_node_pool = true

  // Disable local and certificate auth
  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  // Enable google-groups for RBAC
  authenticator_groups_config {
    security_group = "gke-security-groups@kubernetes.io"
  }

  // Enable workload identity for GCP IAM
  workload_identity_config {
    identity_namespace = "${data.google_project.project.id}.svc.id.goog"
  }

  // Enable Stackdriver Kubernetes Monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  // Set maintenance time
  maintenance_policy {
    daily_maintenance_window {
      start_time = "11:00" // (in UTC), 03:00 PST
    }
  }

  // Restrict master to Google IP space; use Cloud Shell to access
  master_authorized_networks_config {
  }

  // Enable GKE Usage Metering
  resource_usage_export_config {
    enable_network_egress_metering = true
    bigquery_destination {
      dataset_id = google_bigquery_dataset.usage_metering.dataset_id
    }
  }

  // Enable GKE Network Policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  // Configure cluster addons
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  // Enable PodSecurityPolicy enforcement
  pod_security_policy_config {
    enabled = false // TODO: we should turn this on
  }

  // Enable VPA
  vertical_pod_autoscaling {
    enabled = true
  }
}
