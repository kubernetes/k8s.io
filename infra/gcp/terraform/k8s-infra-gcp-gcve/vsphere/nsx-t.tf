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

      dhcp_generic_option {
        # Set correct MTU to avoid package drops.
        code = "26"
        values = [ "1348" ]
      }
    }
  }
}

# Static routes to the internet as workaround via the gateway vm at 192.168.32.8.
# This is a workaround for a gcve connectivity issue which limits  requests to 64 for a certain amount of time.
# Without this created VMs may e.g. fail during provisioning due to hitting image pull backoffs and thus timeouts.
resource "nsxt_policy_static_route" "route1" {
  display_name = "worakround route to ${each.value} via gateway vm"
  gateway_path = data.nsxt_policy_tier1_gateway.tier1_gw.path

  network      = "${each.value}"

  next_hop {
    admin_distance = "1"
    ip_address     = "192.168.32.8"
  }

  for_each = toset([
    "0.0.0.0/5",
    "8.0.0.0/7",
    "11.0.0.0/8",
    "12.0.0.0/6",
    "16.0.0.0/4",
    "32.0.0.0/3",
    "64.0.0.0/2",
    "128.0.0.0/3",
    "160.0.0.0/5",
    "168.0.0.0/6",
    "172.0.0.0/12",
    "172.32.0.0/11",
    "172.64.0.0/10",
    "172.128.0.0/9",
    "173.0.0.0/8",
    "174.0.0.0/7",
    "176.0.0.0/4",
    "192.0.0.0/9",
    "192.128.0.0/11",
    "192.160.0.0/13",
    "192.169.0.0/16",
    "192.170.0.0/15",
    "192.172.0.0/14",
    "192.176.0.0/12",
    "192.192.0.0/10",
    "193.0.0.0/8",
    "194.0.0.0/7",
    "196.0.0.0/6",
    "200.0.0.0/5",
    "208.0.0.0/4",
    "224.0.0.0/3",
  ])
}
