/**
 * Copyright 2020 The Kubernetes Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
variable "project_name" {
  description = "The name of the project in which to provision the node_pool"
  type        = string
}

variable "cluster_name" {
  description = "The name of the cluster to attach this node_pool to"
  type        = string
}

variable "location" {
  description = "The GCP location (region or zone) where the node_pool should be located"
  type        = string
}

variable "name" {
  description = "The name to use for this node_pool"
  type        = string
}

variable "initial_count" {
  description = "The initial_node_count of this node_pool"
  type        = string
}

variable "min_count" {
  description = "The min_node_count of this node_pool"
  type        = string
}

variable "max_count" {
  description = "The max_node_count of this node_pool"
  type        = string
}

variable "machine_type" {
  description = "The machine_type of this node_pool"
  type        = string
}

variable "image_type" {
  description = "The image_type of this node_pool"
  type        = string
  default     = "COS"
}

variable "disk_size_gb" {
  description = "The disk_size_gb of this node_pool"
  type        = string
}

variable "disk_type" {
  description = "The disk_type of this node_pool"
  type        = string
}

variable "labels" {
  description = "The labels to apply to this node_pool"
  type        = map(string)
  default     = {}
}

# Terraform docs suggest not using terraform to manage taints, because GKE is going
# to auto-apply taints if certain features are enabled, and terraform doesn't do well
# when something else is managing the same thing it's managing.
#
# So this is mostly here to describe intent. It will assign taints at creation time,
# but cannot be used to ensure the taints remain applied throughout the node pool's
# lifecycle
#
# ref: https://www.terraform.io/docs/providers/google/r/container_cluster.html#taint
variable "taints" {
  description = "The taints to apply to this node_pool upon creation (NOTE: changes will be ignored throughout lifecycle)"
  type        = list(object({ key = string, value = string, effect = string }))
  default     = []
}

variable "service_account" {
  description = "The email address of the GCP Service Account to be associated with nodes in this node_pool"
  type        = string
}
