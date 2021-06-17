/*
This file defines:
- GCP Service Account for nodes
- Bigquery dataset for usage metering
- GKE cluster configuration

Note that it does not configure any node pools; this is done in a separate file.
*/

locals {
  cluster_name                       = "aaa"         // This is the name of the cluster defined in this file
  cluster_location                   = "us-central1" // This is the GCP location (region or zone) where the cluster should be created
  bigquery_location                  = "US"          // This is the bigquery specific location where the dataset should be created
  scalability_tests_logs_bucket_name = "k8s-infra-scalability-tests-logs" // Name of the bucket for the scalability test results
}

// Create SA for nodes
resource "google_service_account" "cluster_node_sa" {
  project      = data.google_project.project.project_id
  account_id   = "gke-nodes-${local.cluster_name}"
  display_name = "Nodes in GKE cluster '${local.cluster_name}'"
}

// Add roles for SA
resource "google_project_iam_member" "cluster_node_sa_logging" {
  project = data.google_project.project.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cluster_node_sa.email}"
}
resource "google_project_iam_member" "cluster_node_sa_monitoring_viewer" {
  project = data.google_project.project.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.cluster_node_sa.email}"
}
resource "google_project_iam_member" "cluster_node_sa_monitoring_metricwriter" {
  project = data.google_project.project.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cluster_node_sa.email}"
}

// BigQuery dataset for usage data
resource "google_bigquery_dataset" "usage_metering" {
  dataset_id  = replace("usage_metering_${local.cluster_name}", "-", "_")
  project     = data.google_project.project.project_id
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
  delete_contents_on_destroy = false
}

// Create GKE cluster, but with no node pools. Node pools can be provisioned below
resource "google_container_cluster" "cluster" {
  name     = local.cluster_name
  location = local.cluster_location

  provider = google-beta
  project  = data.google_project.project.project_id

  // GKE clusters are critical objects and should not be destroyed
  // IMPORTANT: should be false on test clusters
  lifecycle {
    prevent_destroy = true
  }

  // Network config
  network = "default"
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.40.0.0/14"
    services_ipv4_cidr_block = "10.107.16.0/20"
  }

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

  // Release Channel subscriptions. See https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels
  release_channel {
    channel = "STABLE"
  }

  // Enable google-groups for RBAC
  authenticator_groups_config {
    security_group = "gke-security-groups@kubernetes.io"
  }

  // Enable workload identity for GCP IAM
  workload_identity_config {
    identity_namespace = "${data.google_project.project.project_id}.svc.id.goog"
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

  // Enable NAP
  cluster_autoscaling {
    enabled = true
    resource_limits {
      resource_type = "cpu"
      minimum       = 2
      maximum       = 64
    }
    resource_limits {
      resource_type = "memory"
      maximum       = 256
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

// Bucket for scalability tests results
resource "google_storage_bucket" "scalability_tests_logs" {
  project = data.google_project.project.project_id
  name    = local.scalability_tests_logs_bucket_name

  uniform_bucket_level_access = true
}

data "google_iam_policy" "scalability_tests_logs_bindings" {
  // Ensure k8s-infra-prow-oncall has admin privileges, and keep existing
  // legacy bindings since we're overwriting all existing bindings below
  binding {
    members = [
      "group:k8s-infra-prow-oncall@kubernetes.io",
    ]
    role = "roles/storage.admin"
  }
  binding {
    members = [
      "group:k8s-infra-prow-oncall@kubernetes.io",
      "projectEditor:${data.google_project.project.project_id}",
      "projectOwner:${data.google_project.project.project_id}",
    ]
    role = "roles/storage.legacyBucketOwner"
  }
  binding {
    members = [
      "projectViewer:${data.google_project.project.project_id}",
    ]
    role = "roles/storage.legacyBucketReader"
  }
  // Ensure prow-build serviceaccount can write to bucket
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com",
    ]
  }
  // Ensure bucket is world readable
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "allUsers"
    ]
  }
}

// Authoritative iam-policy: replaces any existing policy attached to the bucket
resource "google_storage_bucket_iam_policy" "scalability_tests_logs_policy" {
  bucket      = google_storage_bucket.scalability_tests_logs.name
  policy_data = data.google_iam_policy.scalability_tests_logs_bindings.policy_data
}