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

# Creates a DHCP Server for the workload network.
resource "nsxt_policy_dhcp_server" "k8s-ci-dhcp" {
  display_name      = "k8s-ci-dhcp"
  description       = "Terraform provisioned DhcpServerConfig"
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  lease_time        = 600
  server_addresses  = ["192.168.32.10/21"]
}

# Creates the subnet for hosting the VM workload network.
resource "nsxt_policy_segment" "k8s-ci" {
  display_name      = "k8s-ci"
  connectivity_path = data.nsxt_policy_tier1_gateway.tier1_gw.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
  dhcp_config_path = nsxt_policy_dhcp_server.k8s-ci-dhcp.path

  subnet {
    cidr        = "192.168.32.1/21"
    # This is the DHCP range used for created VMs.
    # The IP range 192.168.35.0 - 192.168.37.127 is used for VIPs (e.g. via kube-vip)
    # and is assigned to boskos projects.
    dhcp_ranges = ["192.168.32.11-192.168.33.255"]

    dhcp_v4_config {
      server_address = "192.168.32.2/21"
      dns_servers    = [var.gcve_dns_server]
      lease_time     = 600
    }
  }
}
