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

variable "subscription_id" {
  type = string
}

variable "container_registry_scope" {
  type = string
}

variable "e2eprivate_registry_scope" {
  type    = string
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

resource "azurerm_role_definition" "gmsa_custom_role" {
  name        = "gMSA"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Required permissions for gmsa to read properties of subscriptions and managed identities"
  
  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/read",
      "Microsoft.ManagedIdentity/userAssignedIdentities/read"
    ]
    not_actions = []
  }
  
  assignable_scopes = [
    "/subscriptions/${var.subscription_id}"
  ]
}

resource "azurerm_role_assignment" "gmsa_role_assignment" {
  principal_id   = azurerm_user_assigned_identity.domain_vm_identity.principal_id
  role_definition_name = azurerm_role_definition.gmsa_custom_role.name
  scope          = "/subscriptions/${var.subscription_id}"
  depends_on     = [azurerm_user_assigned_identity.domain_vm_identity]
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
