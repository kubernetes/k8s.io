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

variable "tenant_id" {
  type = string
}

variable "identities" {
  type = object({
    domain_vm_identity_id = string
    gmsa_user_identity_id = string
  })
}

resource "azurerm_key_vault" "capz_ci_gmsa" {
  name                = "capz-ci-gmsa-community"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"
}

resource "azurerm_key_vault_access_policy" "access_policy_domain_vm_identity" {
  key_vault_id = azurerm_key_vault.capz_ci_gmsa.id
  tenant_id    = var.tenant_id
  object_id    = var.identities.domain_vm_identity_id
  secret_permissions = [
    "Set"
  ]
}

resource "azurerm_key_vault_access_policy" "access_policy_gmsa_user_identity" {
  key_vault_id = azurerm_key_vault.capz_ci_gmsa.id
  tenant_id    = var.tenant_id
  object_id    = var.identities.gmsa_user_identity_id
  secret_permissions = [
    "Get"
  ]
}

output "key_vault_id" {
  value = azurerm_key_vault.capz_ci_gmsa.id
}
