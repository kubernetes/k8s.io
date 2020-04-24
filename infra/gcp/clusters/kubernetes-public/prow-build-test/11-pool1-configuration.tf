/*
This file defines:
- Node pool for pool1

Note: If you wish to create additional node pools, please duplicate this file
and change the resource name, name_prefix, and any other cluster specific settings.
*/

resource "google_container_node_pool" "pool1" {
  name_prefix = "pool1-"
  location    = google_container_cluster.cluster.location
  cluster     = google_container_cluster.cluster.name

  provider = google-beta
  project  = data.google_project.project.id

  // Start with a single node
  initial_node_count = 1

  // Auto repair, and auto upgrade nodes to match the master version
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  // Autoscale the cluster as needed. Note that these values will be multiplied
  // by 3, as the cluster will exist in three zones
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  // Set machine type, and enable all oauth scopes tied to the service account
  node_config {
    // k8s-prow-builds uses n1-highmem-8
    machine_type = "n1-highmem-2"
    // k8s-prow-builds uses 250
    disk_size_gb = 100
    // k8s-prow-builds uses pd-ssd
    disk_type    = "pd-ssd"

    service_account = google_service_account.cluster_node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    // Needed for workload identity
    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  // If we need to destroy the node pool, create the new one before destroying
  // the old one
  lifecycle {
    create_before_destroy = true
  }
}
