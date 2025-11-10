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
variable "ibmcloud_api_key" {
  type        = string
  description = "IBM Cloud API key"
  sensitive   = true
}

variable "region" {
  type        = string
  description = "IBM Cloud region"
  default     = "eu-de"
}

variable "zone" {
  type        = string
  description = "IBM Cloud zone"
  default     = "eu-de-1"
}

variable "image_name" {
  type        = string
  description = "Image ID for instances"
  default     = "ibm-ubuntu-24-04-3-minimal-s390x-2"
}

variable "keypair_name" {
  type        = string
  description = "SSH key pair name"
  default     = "k8s-sshkey"
}

variable "secrets_manager_id" {
  type        = string
  description = "The instance ID of your secrets manager"
  default     = ""

  validation {
    condition     = var.secrets_manager_id != ""
    error_message = "The secrets_manager_id is required and cannot be empty."
  }
}

variable "control_plane_node_count" {
  description = "Number of control plane nodes to create"
  type        = number
  default     = 5
}

variable "control_plane_node_profile" {
  description = "The profile to use for all control plane nodes"
  type        = string
  default     = "bz2-8x32"
}

variable "control_plane_boot_volume_size" {
  description = "The boot volume size (in GB) for all control plane nodes"
  type        = number
  default     = 100
}

variable "compute_node_count" {
  description = "Number of compute worker nodes to create"
  type        = number
  default     = 10
}

variable "compute_node_profile" {
  description = "The profile to use for all compute nodes"
  type        = string
  default     = "bz2-8x32"
}

variable "compute_boot_volume_size" {
  description = "The boot volume size (in GB) for all compute nodes"
  type        = number
  default     = 100
}

variable "connection_timeout" {
  description = "Timeout in minutes for SSH connections"
  type        = number
  default     = 2
}

variable "bastion_boot_volume_size" {
  description = "Size of the bastion boot volume in GB"
  type        = number
  default     = 100
}

variable "bastion_private_ip" {
  description = "Private IP address for the bastion's secondary interface"
  type        = string
  default     = "192.168.100.10"
}

variable "bastion_profile" {
  description = "Instance profile for the bastion host"
  type        = string
  default     = "bz2-8x32"
}

variable "api_server_port" {
  description = "Port for the Kubernetes API server"
  type        = number
  default     = 6443
}
