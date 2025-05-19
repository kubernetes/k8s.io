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

data "nsxt_policy_tier1_gateway" "tier1_gw" {
  display_name = "Tier1"
}

data "nsxt_policy_transport_zone" "overlay_tz" {
  display_name = "TZ-OVERLAY"
}

data "nsxt_policy_edge_cluster" "edge_cluster" {
  display_name = "edge-cluster"
}

resource "nsxt_policy_dhcp_server" "k8s-ci-dhcp" {
  display_name      = "k8s-ci-dhcp"
  description       = "Terraform provisioned DhcpServerConfig"
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  lease_time        = 600
  server_addresses  = ["192.168.32.10/21"]
}


resource "nsxt_policy_segment" "k8s-ci" {
  display_name      = "k8s-ci"
  connectivity_path = data.nsxt_policy_tier1_gateway.tier1_gw.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
  dhcp_config_path = nsxt_policy_dhcp_server.k8s-ci-dhcp.path

  subnet {
    cidr        = "192.168.32.1/21"
    dhcp_ranges = ["192.168.32.10-192.168.32.255"]

    dhcp_v4_config {
      server_address = "192.168.32.2/21"
      dns_servers    = [var.gcve_dns_server]
      lease_time     = 600
    }
  }
}
