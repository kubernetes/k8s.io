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

resource "google_container_node_pool" "node_pool" {
  provider = google-beta

  // TODO ??
  // name = var.name
  name_prefix = "${var.name}-"

  project     = var.project_name
  location    = var.location
  cluster     = var.cluster_name

  // Auto repair, and auto upgrade nodes to match the master version
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  // Autoscale the cluster as needed. Note if using a regional cluster these values will be multiplied by 3
  initial_node_count = var.min_count
  autoscaling {
    min_node_count = var.min_count
    max_node_count = var.max_count
  }

  // Set machine type, and enable all oauth scopes tied to the service account
  node_config {
    image_type   = var.image_type
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type

    service_account = var.service_account
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
