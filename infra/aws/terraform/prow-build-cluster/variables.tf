/*
Copyright 2023 The Kubernetes Authors.

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

variable "eks_cluster_admins" {
  type        = list(string)
  description = "List of maintainers that have administrator access to the cluster."
  default     = []
}

variable "eks_cluster_viewers" {
  type        = list(string)
  description = "List of maintainers that have view access to the cluster."
  default     = []
}

# This variable is required in the installation process as Terraform
# cannot plan Kubernetes resources as a cluster is yet to be created.
variable "deploy_kubernetes_resources" {
  type        = bool
  description = "Deploy Kubernetes resources defined by Terraform."
  default     = true
  nullable    = false
}

# We need this information to be able to assume the role. We can't automatically determine it with caller_identity
# because that would cause a dependency cycle.
variable "aws_account_id" {
  type        = string
  description = "AWS account ID"
  default     = ""
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC"
}

variable "vpc_secondary_cidr_blocks" {
  type        = list(string)
  description = "Additional CIDRs to attach to the VPC"
}

variable "vpc_public_subnet" {
  type        = list(string)
  description = "Public subnets (one per AZ)"
}

variable "vpc_private_subnet" {
  type        = list(string)
  description = "Private subnets (one per AZ)"
}

variable "vpc_intra_subnet" {
  type        = list(string)
  description = "Intra subnets (one per AZ, subnet without access to external services)"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "cluster_region" {
  type        = string
  description = "AWS region of the EKS cluster"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version of the EKS control plane"
}

variable "node_group_version_us_east_2a" {
  type        = string
  description = "Kubernetes version of the EKS-managed node group in US East 2a"
}

variable "node_group_version_us_east_2b" {
  type        = string
  description = "Kubernetes version of the EKS-managed node group in US East 2b"
}

variable "node_group_version_us_east_2c" {
  type        = string
  description = "Kubernetes version of the EKS-managed node group in US East 2c"
}

variable "node_group_version_stable" {
  type        = string
  description = "Kubernetes version of the EKS-managed node group (stable)"
}

variable "node_instance_types_us_east_2a" {
  type        = list(string)
  description = "Instance sizes to use for EKS node group in US East 2a"
}

variable "node_instance_types_us_east_2b" {
  type        = list(string)
  description = "Instance sizes to use for EKS node group in US East 2b"
}

variable "node_instance_types_us_east_2c" {
  type        = list(string)
  description = "Instance sizes to use for EKS node group in US East 2c"
}

variable "node_instance_types_stable" {
  type        = list(string)
  description = "Instance sizes to use for stable EKS node group"
}

variable "node_volume_size" {
  type        = number
  description = "Volume size per node to use for EKS node group"
}

variable "node_min_size_us_east_2a" {
  type        = number
  description = "Minimum number of nodes in the EKS node group in US East 2a"
}

variable "node_min_size_us_east_2b" {
  type        = number
  description = "Minimum number of nodes in the EKS node group in US East 2b"
}

variable "node_min_size_us_east_2c" {
  type        = number
  description = "Minimum number of nodes in the EKS node group in US East 2c"
}

variable "node_max_size_us_east_2a" {
  type        = number
  description = "Maximum number of nodes in the EKS node group in US East 2a"
}

variable "node_max_size_us_east_2b" {
  type        = number
  description = "Maximum number of nodes in the EKS node group in US East 2b"
}

variable "node_max_size_us_east_2c" {
  type        = number
  description = "Maximum number of nodes in the EKS node group in US East 2c"
}

variable "node_desired_size_us_east_2a" {
  type        = number
  description = "Desired number of nodes in the EKS node group in US East 2a"
}

variable "node_desired_size_us_east_2b" {
  type        = number
  description = "Desired number of nodes in the EKS node group in US East 2b"
}

variable "node_desired_size_us_east_2c" {
  type        = number
  description = "Desired number of nodes in the EKS node group in US East 2c"
}

variable "node_desired_size_stable" {
  type        = number
  description = "Desired number of nodes in the stable EKS node group"
}

variable "node_max_unavailable_percentage" {
  type        = number
  description = "Maximum unavailable nodes in a node group"
}

variable "node_taints_build" {
  type    = list(map(string))
  default = []
}

variable "node_taints_stable" {
  type    = list(map(string))
  default = []
}

variable "node_labels_build" {
  type    = map(string)
  default = {}
}

variable "node_labels_stable" {
  type    = map(string)
  default = {}
}

variable "additional_node_group_tags_build" {
  type    = map(string)
  default = {}
}

variable "additional_node_group_tags_stable" {
  type    = map(string)
  default = {}
}

variable "cluster_autoscaler_version" {
  type        = string
  description = "Cluster Autoscaler version to use (must match the EKS version)"
}

variable "bastion_install" {
  type        = bool
  description = "Install bastion hosts allowing to access EKS nodes via ssh."
  default     = false
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.nano"
}

variable "public_key" {
  type        = string
  description = "Used to genereate private key allowing for ssh access to cluster nodes."
}
