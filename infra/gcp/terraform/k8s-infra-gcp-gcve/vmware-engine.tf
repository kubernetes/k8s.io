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
  location    = "us-central1-a"
  name        = "k8s-gcp-gcve-pc"
  project     = var.project_id
  description = "k8s Community vSphere Cluster for CI."
  # TODO(chrischdi): figure out discount and switch to STANDARD
  type = "TIME_LIMITED"
  network_config {
    management_cidr       = "192.168.30.0/24"
    vmware_engine_network = google_vmwareengine_network.vsphere-network.id
  }

  management_cluster {
    cluster_id = "k8s-gcve-cluster"
    node_type_configs {
      node_type_id = "standard-72"
      # TODO: node_count 1 is for the TIME_LIMITED version. Change to `3`.
      node_count = 1
    }
  }
}

resource "google_vmwareengine_network" "vsphere-network" {
  name     = "k8s-gcp-gcve-network"
  project  = var.project_id
  type     = "STANDARD"
  location = "global"
}

resource "google_vmwareengine_network_policy" "external-access-rule-np" {
  name                  = "k8s-gcp-gcve-network-policy"
  project               = var.project_id
  location              = "us-central1"
  edge_services_cidr    = "192.168.31.0/26"
  vmware_engine_network = google_vmwareengine_network.vsphere-network.id
  internet_access {
    enabled = true
  }
}

resource "google_vmwareengine_network_peering" "prow_peering" {
  name                                = "peer-with-k8s-infra-prow-build"
  project                             = var.project_id
  peer_network                        = "projects/k8s-infra-prow-build/global/networks/default"
  peer_network_type                   = "STANDARD"
  vmware_engine_network               = google_vmwareengine_network.vsphere-network.id
  export_custom_routes_with_public_ip = false
  import_custom_routes_with_public_ip = false
}

resource "google_compute_network" "maintenance-vpc" {
  name                    = "maintenance-vpc-network"
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "maintenance-subnet" {
  name          = "maintenance-subnet"
  project       = var.project_id
  ip_cidr_range = "192.168.28.0/24"
  region        = "us-central1"
  network       = google_compute_network.maintenance-vpc.id
}

resource "google_vmwareengine_network_peering" "maintenance_peering" {
  name                  = "peer-with-maintenance-vpc-network"
  description           = "Peering with maintenance vpc network"
  project               = var.project_id
  peer_network          = google_compute_network.maintenance-vpc.id
  peer_network_type     = "STANDARD"
  vmware_engine_network = google_vmwareengine_network.vsphere-network.id
}

resource "google_compute_firewall" "maintenance-firewall-internet" {
  name    = "maintenance-firewall-internet"
  project = var.project_id
  network = google_compute_network.maintenance-vpc.name

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }
}

resource "google_compute_firewall" "maintenance-firewall-internal" {
  name    = "maintenance-firewall-internal"
  project = var.project_id
  network = google_compute_network.maintenance-vpc.name

  source_ranges = [google_compute_subnetwork.maintenance-subnet.ip_cidr_range]

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
}
