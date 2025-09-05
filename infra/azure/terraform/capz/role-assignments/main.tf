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

# This module maintains all role assignments for our service principal - az-cli-prow

variable "resource_group_name" {
  type = string
}

variable "container_registry_scope" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "e2eprivate_registry_scope" {
  type    = string
}

variable "cloud_provider_user_identity_id" {
  type    = string
}

variable "key_vault_id" {
  type = string
} 

data "azuread_service_principal" "az_service_principal" {
  display_name = "az-cli-prow"
}

resource "azurerm_role_assignment" "rg_contributor" {
  principal_id         = data.azuread_service_principal.az_service_principal.object_id
  role_definition_name = "Contributor"
  scope                = "/subscriptions/${var.subscription_id}"
}

resource "azurerm_role_assignment" "rg_contributor_cloud_provider" {
  principal_id         = var.cloud_provider_user_identity_id
  role_definition_name = "Contributor"
  scope                = "/subscriptions/${var.subscription_id}"
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  principal_id         = data.azuread_service_principal.az_service_principal.object_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = "/subscriptions/${var.subscription_id}"
}

resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = data.azuread_service_principal.az_service_principal.object_id
  role_definition_name = "AcrPull"
  scope                = var.container_registry_scope
}

resource "azurerm_role_assignment" "acr_pull_private" {
  principal_id         = var.cloud_provider_user_identity_id
  role_definition_name = "AcrPull"
  scope                = var.e2eprivate_registry_scope
}

resource "azurerm_role_assignment" "acr_pull_cloud_provider" {
  principal_id         = var.cloud_provider_user_identity_id
  role_definition_name = "AcrPull"
  scope                = var.container_registry_scope
}

resource "azurerm_role_definition" "custom_role" {
  name  = "WriteAccessOnly"
  scope = "/subscriptions/${var.subscription_id}"

  permissions {
    actions = [
      "Microsoft.Authorization/roleAssignments/write"
    ]
    not_actions = []
  }

  assignable_scopes = [
    "/subscriptions/${var.subscription_id}"
  ]
}

resource "azurerm_role_assignment" "sp_custom_role_assignment" {
  principal_id         = data.azuread_service_principal.az_service_principal.object_id
  role_definition_name = azurerm_role_definition.custom_role.name
  scope                = "/subscriptions/${var.subscription_id}"
}

resource "azurerm_key_vault_access_policy" "access_policy_gmsa_sp" {
  key_vault_id = var.key_vault_id
  tenant_id    = data.azuread_service_principal.az_service_principal.application_tenant_id
  object_id    = data.azuread_service_principal.az_service_principal.object_id
  secret_permissions = [
    "Get",
    "Delete",
    "List",
    "Purge"
  ]
}
