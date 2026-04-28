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
output "bastion_private_ips_map" {
  description = "Private IP addresses of the bastion hosts"
  value       = { for k, instance in ibm_is_instance.bastion : k => instance.primary_network_interface[0].primary_ipv4_address }
}

output "bastion_public_ips_map" {
  description = "Public IP addresses of the bastion hosts, keyed by instance name"
  value       = { for k, fip in ibm_is_floating_ip.bastion_fip : k => fip.address }
}

output "control_plane_node_ips_map" {
  description = "Private IP addresses of the control plane nodes, keyed by node name"
  value       = { for k, instance in ibm_is_instance.control_plane : k => instance.primary_network_interface[0].primary_ipv4_address }
}

output "worker_node_ips_map" {
  description = "Private IP addresses of the worker nodes, keyed by node name"
  value       = { for k, instance in ibm_is_instance.compute : k => instance.primary_network_interface[0].primary_ipv4_address }
}

output "api_load_balancer_hostname" {
  description = "Hostname of the Kubernetes API load balancer"
  value       = ibm_is_lb.public.hostname
}
output "subnet_cidr" {
  description = "CIDR block of the public subnet"
  value       = data.ibm_is_subnet.subnet.ipv4_cidr_block
}
