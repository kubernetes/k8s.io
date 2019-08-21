/*
This file defines:
- Node pool for pool-1

Note: If you wish to create additional node pools, please duplicate this file
and change the resource name, name_prefix, and any other cluster specific settings.
*/

resource "google_container_node_pool" "pool-1" {
  provider = google-beta

  name_prefix = "pool-1-"
  project     = data.google_project.project.id
  location    = google_container_cluster.cluster.location
  cluster     = google_container_cluster.cluster.name

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
    max_node_count = 20
  }

  // Set machine type, and enable all oauth scopes tied to the service account
  node_config {
    machine_type    = "n1-standard-4"
    service_account = google_service_account.cluster_node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    // Restrict metadata config from workload
    workload_metadata_config {
      node_metadata = "SECURE"
    }
  }

  // If we need to destroy the node pool, create the new one before destroying
  // the old one
  lifecycle {
    create_before_destroy = true
  }
}
