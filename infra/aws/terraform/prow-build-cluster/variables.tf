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
  description = "List of maintainers that have administrator access to the cluster"
  type        = list(string)
  default     = []
}

variable "eks_cluster_viewers" {
  description = "List of maintainers that have view access to the cluster"
  type        = list(string)
  default     = []
}

# This variable is required in the installation process as Terraform
# cannot plan Kubernetes resources as a cluster is yet to be created.
variable "deploy_kubernetes_resources" {
  description = "Deploy Kubernetes resources defined by Terraform"
  type        = bool
  default     = true
  nullable    = false
}

# We need this information to be able to assume the role. We can't automatically determine it with caller_identity
# because that would cause a dependency cycle.
variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR of the VPC"
  type        = string
}

variable "vpc_secondary_cidr_blocks" {
  description = "Additional CIDRs to attach to the VPC"
  type        = list(string)
}

variable "vpc_public_subnet" {
  description = "Public subnets (one per AZ)"
  type        = list(string)
}

variable "vpc_private_subnet" {
  description = "Private subnets (one per AZ)"
  type        = list(string)
}

variable "vpc_intra_subnet" {
  description = "Intra subnets (one per AZ, subnet without access to external services)"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_region" {
  description = "AWS region of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version of the EKS control plane"
  type        = string
}

variable "node_group_version_blue" {
  description = "Kubernetes version of the EKS-managed node group (blue)"
  type        = string
}

variable "node_group_version_green" {
  description = "Kubernetes version of the EKS-managed node group (green)"
  type        = string
}

variable "node_ami_blue" {
  description = "EKS optimized AMI to be used for blue Node groups"
  type        = string
}

variable "node_ami_green" {
  description = "EKS optimized AMI to be used for green node group"
  type        = string
}

variable "node_instance_types_blue" {
  description = "Instance sizes to use for blue EKS node group"
  type        = list(string)
}

variable "node_instance_types_green" {
  description = "Instance sizes to use for green EKS node group"
  type        = list(string)
}

variable "node_volume_size" {
  description = "Volume size per node to use for EKS node group"
  type        = number
}

variable "node_min_size_blue" {
  description = "Minimum number of nodes in the blue EKS node group"
  type        = number
}

variable "node_min_size_green" {
  description = "Minimum number of nodes in the green EKS node group"
  type        = number
}

variable "node_max_size_blue" {
  description = "Maximum number of nodes in the blue EKS node group"
  type        = number
}

variable "node_max_size_green" {
  description = "Maximum number of nodes in the green EKS node group"
  type        = number
}

variable "node_desired_size_blue" {
  description = "Desired number of nodes in the blue EKS node group"
  type        = number
}

variable "node_desired_size_green" {
  description = "Desired number of nodes in the green EKS node group"
  type        = number
}

variable "node_max_unavailable_percentage" {
  description = "Maximum unavailable nodes in a node group"
  type        = number
}

variable "node_taints_blue" {
  description = "Taints applied to the nodes created by the nodegroup"
  type        = list(map(string))
  default     = []
}

variable "node_taints_green" {
  description = "Taints applied to the nodes created by the nodegroup"
  type        = list(map(string))
  default     = []
}

variable "node_labels_blue" {
  description = "Labels applied to the nodes created by the nodegroup"
  type        = map(string)
  default     = {}
}

variable "node_labels_green" {
  description = "Labels applied to the nodes created by the nodegroup"
  type        = map(string)
  default     = {}
}

variable "additional_node_group_tags_blue" {
  description = "Additional tags to be added to the nodegroup"
  type        = map(string)
  default     = {}
}

variable "additional_node_group_tags_green" {
  description = "Additional tags to be added to the nodegroup"
  type        = map(string)
  default     = {}
}

variable "cluster_autoscaler_version" {
  description = "Cluster Autoscaler version to use (must match the EKS version)"
  type        = string
}

variable "bastion_install" {
  description = "Install bastion hosts allowing to access EKS nodes via ssh"
  type        = bool
  default     = false
}

variable "public_key" {
  description = "Used to genereate private key allowing for ssh access to cluster nodes"
  type        = string
}
