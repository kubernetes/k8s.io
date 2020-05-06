/**
 * Copyright 2020 The Kubernetes Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Create GCP SA for nodes
resource "google_service_account" "cluster_node_sa" {
  project      = var.project_name
  account_id   = "gke-nodes-${var.cluster_name}"
  display_name = "Nodes in GKE cluster '${var.cluster_name}'"
}

// Add roles for SA
resource "google_project_iam_member" "cluster_node_sa_logging" {
  project = var.project_name
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cluster_node_sa.email}"
}
resource "google_project_iam_member" "cluster_node_sa_monitoring_viewer" {
  project = var.project_name
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.cluster_node_sa.email}"
}
resource "google_project_iam_member" "cluster_node_sa_monitoring_metricwriter" {
  project = var.project_name
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cluster_node_sa.email}"
}

// BigQuery dataset for usage data
resource "google_bigquery_dataset" "usage_metering" {
  dataset_id  = replace("usage_metering_${var.cluster_name}", "-", "_")
  project     = var.project_name
  description = "GKE Usage Metering for cluster '${var.cluster_name}'"
  location    = var.bigquery_location

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
  name     = var.cluster_name
  location = var.cluster_location

  provider = google-beta
  project  = var.project_name

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
    identity_namespace = "${var.project_name}.svc.id.goog"
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
