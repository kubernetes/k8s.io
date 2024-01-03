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
- GCP Service Account for nodes
- Bigquery dataset for usage metering
- GKE cluster configuration

Note that it does not configure any node pools; this is done in a separate file.
*/

locals {
  cluster_name      = "aaa"         // This is the name of the cluster defined in this file
  cluster_location  = "us-central1" // This is the GCP location (region or zone) where the cluster should be created
  bigquery_location = "US"          // This is the bigquery specific location where the dataset should be created
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

  // Release Channel subscriptions. See https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels
  release_channel {
    channel = "REGULAR"
  }

  // Enable google-groups for RBAC
  authenticator_groups_config {
    security_group = "gke-security-groups@kubernetes.io"
  }

  // Enable workload identity for GCP IAM
  workload_identity_config {
    workload_pool = "${data.google_project.project.project_id}.svc.id.goog"
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

  // Enable GKE workloads monitoring
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS"
    ]

    managed_prometheus {
      enabled = true
    }
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
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
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

  // Enable Shielded nodes
  enable_shielded_nodes = false

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
    auto_provisioning_defaults {
      image_type = "COS_CONTAINERD"
    }
  }

  // Enable VPA
  vertical_pod_autoscaling {
    enabled = true
  }
}
