/*
Copyright 2025 The Kubernetes Authors.

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

resource "google_vmwareengine_private_cloud" "vsphere-cluster" {
  location    = "us-central1"
  name        = "k8s-gcp-gcve-pc"
  project     = local.project_id
  description = "k8s Community vSphere Cluster for CI."
  # TODO(chrischdi): figure out discount and switch to STANDARD
  type        = "TIME_LIMITED"
  network_config {
    management_cidr       = "192.168.30.0/28"
    vmware_engine_network = google_vmwareengine_network.vsphere-network.id
  }

  management_cluster {
    cluster_id = "k8s-gcve-cluster"
    node_type_configs {
      node_type_id = "standard-72"
      # TODO: node_count 1 is for the TIME_LIMITED version. Change to `3`.
      node_count   = 1
    }
  }
}

resource "google_vmwareengine_network" "vsphere-network" {
  name     = "k8s-gcp-gcve-network"
  project  = local.project_id
  type     = "STANDARD"
  location = "us-central1"
}

resource "google_vmwareengine_network_peering" "prow_peering" {
    name                  = "peer-with-k8s-infra-prow-build"
    description           = "Peering with prow build cluster"
    project               = local.project_id
    peer_network          = "projects/k8s-infra-prow-build/global/networks/default"
    peer_network_type     = "STANDARD"
    vmware_engine_network = google_vmwareengine_network.vsphere-network.id
}
