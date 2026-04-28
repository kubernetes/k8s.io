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

variable "image_name" {
  type        = string
  description = "The name of the image that you want to use for the nodes"
  default     = "CentOS-Stream-10"

  validation {
    condition     = var.image_name != ""
    error_message = "The image_name is required and cannot be empty."
  }
}
