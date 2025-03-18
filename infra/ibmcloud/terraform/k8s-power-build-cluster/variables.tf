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

################################################################
# Configure the IBM Cloud provider
################################################################
variable "ibmcloud_api_key" {
  type        = string
  description = "IBM Cloud API key associated with user's identity"
  sensitive   = true

  validation {
    condition     = var.ibmcloud_api_key != ""
    error_message = "The ibmcloud_api_key is required and cannot be empty."
  }
}

variable "service_instance_id" {
  type        = string
  description = "The cloud instance ID of your account"
  default     = ""

  validation {
    condition     = var.service_instance_id != ""
    error_message = "The service_instance_id is required and cannot be empty."
  }
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

variable "vpc_name" {
  type        = string
  description = "The name of your VPC"
  default     = "k8s-vpc"

  validation {
    condition     = var.vpc_name != ""
    error_message = "The vpc_name is required and cannot be empty."
  }
}

variable "resource_group_name" {
  type        = string
  description = "The name of your resource group"
  default     = "k8s-project"

  validation {
    condition     = var.resource_group_name != ""
    error_message = "The resource_group_name is required and cannot be empty."
  }
}

variable "network_name" {
  type        = string
  description = "The name of the network to be used for deploy operations"
  default     = "private-net"

  validation {
    condition     = var.network_name != ""
    error_message = "The network_name is required and cannot be empty."
  }
}

variable "image_name" {
  type        = string
  description = "The name of the image that you want to use for the nodes"
  default     = "CentOS-Stream-9"

  validation {
    condition     = var.image_name != ""
    error_message = "The image_name is required and cannot be empty."
  }
}

variable "keypair_name" {
  type        = string
  description = "The name of the keypair that you want to use for connecting with the nodes"
  default     = "k8s-sshkey"

  validation {
    condition     = var.keypair_name != ""
    error_message = "The keypair_name is required and cannot be empty."
  }
}

variable "ibmcloud_region" {
  type        = string
  description = "The IBM Cloud region where you want to create the resources"
  default     = "osa"

  validation {
    condition     = var.ibmcloud_region != ""
    error_message = "The ibmcloud_region is required and cannot be empty."
  }
}

variable "ibmcloud_zone" {
  type        = string
  description = "The zone of an IBM Cloud region where you want to create Power System resources"
  default     = "osa21"

  validation {
    condition     = var.ibmcloud_zone != ""
    error_message = "The ibmcloud_zone is required and cannot be empty."
  }
}

variable "vpc_region" {
  type        = string
  description = "IBM Cloud VPC Infrastructure region."
  default     = "jp-osa"

  validation {
    condition     = var.vpc_region != ""
    error_message = "The vpc_region is required and cannot be empty."
  }
}

################################################################
# Configure the Instance details
################################################################

variable "bastion" {
  type = object({ memory = string, processors = string })
  default = {
    memory     = "8"
    processors = "0.5"
  }
}

variable "control_plane" {
  default = {
    count      = 3
    memory     = "8"
    processors = "0.5"
  }
  validation {
    condition     = var.control_plane["count"] == 3
    error_message = "The control_plane.count value should be 3."
  }
}

variable "compute" {
  default = {
    count      = 2
    memory     = "8"
    processors = "0.5"
  }
}

variable "processor_type" {
  type        = string
  description = "The type of processor mode (shared/dedicated)"
  default     = "shared"
}

variable "system_type" {
  type        = string
  description = "The type of system"
  default     = "e980"
}

variable "storage_type" {
  type        = string
  description = "The type of storage"
  default     = "tier0"
}

################################################################
### Instrumentation
################################################################
variable "ssh_agent" {
  type        = bool
  description = "Enable or disable SSH Agent. Can correct some connectivity issues. Default: false"
  default     = false
}

variable "connection_timeout" {
  description = "Timeout in minutes for SSH connections"
  default     = 30
}

variable "bastion_health_status" {
  type        = string
  description = "Specify if bastion should poll for the Health Status to be OK or WARNING. Default is OK."
  default     = "WARNING"
  validation {
    condition     = contains(["OK", "WARNING"], var.bastion_health_status)
    error_message = "The bastion_health_status value must be either OK or WARNING."
  }
}
