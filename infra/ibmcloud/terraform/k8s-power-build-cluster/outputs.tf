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

output "bastion_private_ip" {
  value = data.ibm_pi_instance_ip.bastion_ip.ip
}

output "bastion_private_cidr" {
  value = data.ibm_pi_network.private_network.cidr
}

output "bastion_private_gateway" {
  value = data.ibm_pi_network.private_network.gateway
}

output "bastion_internal_ip" {
  value = data.ibm_pi_instance_ip.bastion_public_ip.ip
}

output "bastion_public_ip" {
  value = data.ibm_pi_instance_ip.bastion_public_ip.external_ip
}

output "control_plane_ips" {
  value = data.ibm_pi_instance_ip.control_plane_ip.*.ip
}

output "compute_ips" {
  value = data.ibm_pi_instance_ip.compute_ip.*.ip
}

output "loadbalancer_hostname" {
  value = module.load_balancer.hostname
}
