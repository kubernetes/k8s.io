/*
Copyright 2026 The Kubernetes Authors.

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


// Create kafka cluster with 3vcpu, 12MB memory and autorebalance
resource "google_managed_kafka_cluster" "mimir_cluster" {
  project    = module.project.project_id
  cluster_id = "mimir-cluster"
  location   = "us-central1"
  capacity_config {
    vcpu_count   = 3
    memory_bytes = 12884901888
  }
  gcp_config {
    access_config {
      network_configs {
        subnet = module.vpc.subnets["us-central1/subnet-01"].id
      }
    }
  }
  rebalance_config {
    mode = "AUTO_REBALANCE_ON_SCALE_UP"
  }
}

// Create mimir-ingest topic with 12 partition count
resource "google_managed_kafka_topic" "mimir_ingest" {
  project            = module.project.project_id
  topic_id           = "mimir-ingest"
  cluster            = google_managed_kafka_cluster.mimir_cluster.cluster_id
  location           = "us-central1"
  partition_count    = 12 # must be >= ingesters per zone
  replication_factor = 3  # Managed Kafka requires >= 3

  // Set max byte to 16MB because mimir default is 15.2MB
  configs = {
    "max.message.bytes" = "16000000"
  }
}
