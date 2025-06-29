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

# Creates the VMware Engine Private Cloud which is a vSphere Cluster including NSX-T.
resource "google_vmwareengine_private_cloud" "vsphere-cluster" {
  location    = "us-central1-a"
  name        = "k8s-gcp-gcve"
  project     = var.project_id
  description = "k8s Community vSphere Cluster for CI."
  type = "STANDARD"
  network_config {
    management_cidr       = "192.168.31.0/24"
    vmware_engine_network = google_vmwareengine_network.vsphere-network.id
  }

  management_cluster {
    cluster_id = "k8s-gcve-cluster"
    node_type_configs {
      node_type_id = "standard-72"
      node_count = 3
    }
  }
}

# Creates the VMware Engine Network for the Private Cloud.
resource "google_vmwareengine_network" "vsphere-network" {
  name     = "k8s-gcp-gcve-network"
  project  = var.project_id
  type     = "STANDARD"
  location = "global"
}

# Creates the Network Policy to allow created virtual machines to reach out to the internet.
resource "google_vmwareengine_network_policy" "external-access-rule-np" {
  name                  = "k8s-gcp-gcve-network-policy"
  project               = var.project_id
  location              = "us-central1"
  edge_services_cidr    = "192.168.27.0/26"
  vmware_engine_network = google_vmwareengine_network.vsphere-network.id
  internet_access {
    enabled = true
  }
}

# Creates the Peering to the prow cluster to allow Pods running in Prow to access vCenter and created VMs in vSphere.
resource "google_vmwareengine_network_peering" "prow_peering" {
  name                                = "peer-with-k8s-infra-prow-build"
  project                             = var.project_id
  peer_network                        = "projects/k8s-infra-prow-build/global/networks/default"
  peer_network_type                   = "STANDARD"
  vmware_engine_network               = google_vmwareengine_network.vsphere-network.id
  export_custom_routes_with_public_ip = false
  import_custom_routes_with_public_ip = false
}

# Creates a maintenance network used for creating Google Compute VM(s) for setup or debugging purposes via ssh or wireguard VPN.
resource "google_compute_network" "maintenance-vpc" {
  name                    = "maintenance-vpc-network"
  project                 = var.project_id
  auto_create_subnetworks = false
}

# Creates the Subnet for the above maintenance network.
resource "google_compute_subnetwork" "maintenance-subnet" {
  name          = "maintenance-subnet"
  project       = var.project_id
  ip_cidr_range = "192.168.28.0/24"
  region        = "us-central1"
  network       = google_compute_network.maintenance-vpc.id
}

# Creates the Peering to the maintenance network to maintenance VMs to access vCenter and created VMs in vSphere.
resource "google_vmwareengine_network_peering" "maintenance_peering" {
  name                  = "peer-with-maintenance-vpc-network"
  description           = "Peering with maintenance vpc network"
  project               = var.project_id
  peer_network          = google_compute_network.maintenance-vpc.id
  peer_network_type     = "STANDARD"
  vmware_engine_network = google_vmwareengine_network.vsphere-network.id
}

# Creates the firewall rules for VMs running in the maintenance network so they can be accessed
# via SSH or to expose wireguard VPN.
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

# Creates the firewall rule to allow any traffic from the maintenance subnet to
# the VMware Engine network or the internet.
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
