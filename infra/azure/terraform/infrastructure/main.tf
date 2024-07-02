# Data source to get the current client configuration
data "azurerm_client_config" "current" {}

# Resource group for CAPZ CI resources
resource "azurerm_resource_group" "capz_ci" {
  location = "eastus"
  name     = "capz-ci"
  tags = {
    DO-NOT-DELETE = "contact capz"
  }
}

# User Assigned Managed Identities
resource "azurerm_user_assigned_identity" "cloud_provider_user_identity" {
  name                = "cloud-provider-user-identity"
  location            = azurerm_resource_group.capz_ci.location
  resource_group_name = azurerm_resource_group.capz_ci.name
  depends_on = [
    azurerm_resource_group.capz_ci,
  ]
}
resource "azurerm_user_assigned_identity" "domain_vm_identity" {
  name                = "domain-vm-identity"
  location            = azurerm_resource_group.capz_ci.location
  resource_group_name = azurerm_resource_group.capz_ci.name
  depends_on = [
    azurerm_resource_group.capz_ci,
  ]
}
resource "azurerm_user_assigned_identity" "gmsa_user_identity" {
  location            = azurerm_resource_group.capz_ci.location
  resource_group_name = azurerm_resource_group.capz_ci.name
  name                = "gmsa-user-identity"
  depends_on = [
    azurerm_resource_group.capz_ci,
  ]
}

# Key Vault for CAPZ CI GMSA
resource "azurerm_key_vault" "capz_ci_gmsa" {
  name                        = "capz-ci-gmsa"
  location                    = azurerm_resource_group.capz_ci.location
  resource_group_name         = azurerm_resource_group.capz_ci.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  depends_on = [
    azurerm_resource_group.capz_ci,
  ]  
}

# Container Registry
resource "azurerm_container_registry" "oidc_capzci" {
  name                = "capzci"
  location            = azurerm_resource_group.capz_ci.location
  resource_group_name = azurerm_resource_group.capz_ci.name
  sku                 = "Standard"
  anonymous_pull_enabled = true
  depends_on = [
    azurerm_resource_group.capz_ci,
  ]
}

# Storage Account
resource "azurerm_storage_account" "oidcissuecapzci" {
  name                     = "oidcissuecapzci"
  location                 = azurerm_resource_group.capz_ci.location
  resource_group_name      = azurerm_resource_group.capz_ci.name
  account_tier             = "Standard"
  min_tls_version          = "TLS1_0"
  account_replication_type = "RAGRS"
  depends_on = [
    azurerm_resource_group.capz_ci,
  ]
}