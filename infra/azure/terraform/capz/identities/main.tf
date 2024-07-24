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

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

resource "azurerm_user_assigned_identity" "cloud_provider_user_identity" {
  name                = "cloud-provider-user-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_user_assigned_identity" "domain_vm_identity" {
  name                = "domain-vm-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_user_assigned_identity" "gmsa_user_identity" {
  name                = "gmsa-user-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

output "cloud_provider_user_identity_id" {
  value = azurerm_user_assigned_identity.cloud_provider_user_identity.principal_id
}

output "domain_vm_identity_id" {
  value = azurerm_user_assigned_identity.domain_vm_identity.principal_id
}

output "gmsa_user_identity_id" {
  value = azurerm_user_assigned_identity.gmsa_user_identity.principal_id
}
