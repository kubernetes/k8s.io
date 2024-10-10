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

provider "azurerm" {
  features {}
}

# Data source to get the current client configuration
data "azurerm_client_config" "current" {}

# TODO: add state maintainence in Azure

# Create a resource group
resource "azurerm_resource_group" "secrets_store_rg" {
  name     = "secrets-store-csi-driver"
  location = "westus2"
  tags = {
    DO-NOT-DELETE = "contact <anramase@microsoft.com>"
  } 
}

# Create a Key Vault
resource "azurerm_key_vault" "secrets_csi_kv" {
  name                        = "secrets-store-csi-e2e"
  location                    = azurerm_resource_group.secrets_store_rg.location
  resource_group_name         = azurerm_resource_group.secrets_store_rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  
  depends_on   = [azurerm_resource_group.secrets_store_rg]
}

# Create a Key Vault access policy for the Service Principal
resource "azurerm_key_vault_access_policy" "kv_access_service_principal" {
  key_vault_id = azurerm_key_vault.secrets_csi_kv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Set", 
    "Get"
  ]
  depends_on   = [azurerm_key_vault.secrets_csi_kv]
}

# Create a secret in the Key Vault
resource "azurerm_key_vault_secret" "kv_secret" {
  name         = "secret1"
  value        = "test"
  key_vault_id = azurerm_key_vault.secrets_csi_kv.id
  depends_on   = [azurerm_key_vault.secrets_csi_kv]
}

# To run the Terraform script
output "key_vault_id" {
  value = azurerm_key_vault.secrets_csi_kv.id
}

output "key_vault_secret_id" {
  value = azurerm_key_vault_secret.kv_secret.id
}
