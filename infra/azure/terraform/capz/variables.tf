/*
Copyright 2024 The Kubernetes Authors.

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

variable "location" {
  type        = string
  default     = "eastus"
  description = "Location of the resource group."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
  default     = "capz-ci"
}

variable "storage_account_name" {
  type        = string
  default     = "k8sprowstoragecomm"
  description = "Name of the storage account."
}

variable "subscription_id" {
  type        = string
  default     = "46678f10-4bbb-447e-98e8-d2829589f2d8"
  description = "Azure Subscription ID to use for the azurerm provider."
}