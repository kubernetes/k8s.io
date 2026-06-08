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
  description = "IBM Cloud API key associated with user's identity"
  sensitive   = true

  validation {
    condition     = var.ibmcloud_api_key != ""
    error_message = "The ibmcloud_api_key is required and cannot be empty."
  }
}
variable "zone" {
  description = "IBM Cloud zone for resources"
  type        = string
  default     = "eu-de-1"
}
variable "region" {
  type        = string
  description = "IBM Cloud region"
  default     = "eu-de"
}
variable "boskos_resources" {
  description = "Boskos VPC resources to create."
  type = map(object({
    zone        = string
    subnet_name = optional(string)
  }))
  default = {
    k8s-s390x-test-vpc-eu-de-1 = {
      zone        = "eu-de-1"
      subnet_name = "k8s-s390x-test-subnet-eu-de-1"
    }
    k8s-s390x-test-vpc-eu-de-2 = {
      zone        = "eu-de-2"
      subnet_name = "k8s-s390x-test-subnet-eu-de-2"
    }
    k8s-s390x-test-vpc-eu-de-3 = {
      zone        = "eu-de-3"
      subnet_name = "k8s-s390x-test-subnet-eu-de-3"
    }
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
