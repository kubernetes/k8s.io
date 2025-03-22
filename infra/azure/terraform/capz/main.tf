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

terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-states-azure"
    storage_account_name = "terraformstatescomm"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

resource "azurerm_resource_provider_registration" "provider-k8s-config" {
  name = "Microsoft.KubernetesConfiguration"

  feature {
    name       = "Extensions"
    registered = true
  }
}

resource "azurerm_resource_provider_registration" "provider-container-service" {
  name = "Microsoft.ContainerService"
}

resource "azurerm_marketplace_agreement" "traefik-agreement" {
  publisher = "containous"
  offer     = "traefik-proxy"
  plan      = "traefik-proxy"
}

# The image-builder project needs the subscription to accept a license agreement before it can build Flatcar linux image.
resource "azurerm_marketplace_agreement" "kinvolk-stable-agreement" {
  publisher = "kinvolk"
  offer     = "flatcar-container-linux-free"
  plan      = "stable"
}

resource "azurerm_marketplace_agreement" "kinvolk-stable2-agreement" {
  publisher = "kinvolk"
  offer     = "flatcar-container-linux-free"
  plan      = "stable-gen2"
}

# Data source to get the current client configuration
data "azurerm_client_config" "current" {}


# Resource group for CAPZ CI resources
resource "azurerm_resource_group" "capz_ci" {
  location = var.location
  name     = var.resource_group_name
  tags = {
    DO-NOT-DELETE = "contact capz"
  }
}

resource "azurerm_storage_account" "k8sprowstorage" {
  name                             = var.storage_account_name
  location                         = var.location
  resource_group_name              = var.resource_group_name
  account_tier                     = "Standard"
  min_tls_version                  = "TLS1_0"
  account_replication_type         = "RAGRS"
  cross_tenant_replication_enabled = true
  depends_on                       = [azurerm_resource_group.capz_ci]
}

# Import identities module
module "identities" {
  source              = "./identities"
  resource_group_name = var.resource_group_name
  location            = var.location
  depends_on          = [azurerm_resource_group.capz_ci]
}

# Import key vault module
module "key_vault" {
  source              = "./key-vault"
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  identities = {
    cloud_provider_user_identity_id = module.identities.cloud_provider_user_identity_id
    domain_vm_identity_id           = module.identities.domain_vm_identity_id
    gmsa_user_identity_id           = module.identities.gmsa_user_identity_id
  }
  depends_on = [azurerm_resource_group.capz_ci]
}

# Import container registry module
module "container_registry" {
  source              = "./container-registry"
  resource_group_name = var.resource_group_name
  location            = var.location
  depends_on          = [azurerm_resource_group.capz_ci]
}

# Import role assignments module
module "role_assignments" {
  source                   = "./role-assignments"
  resource_group_name      = var.resource_group_name
  container_registry_scope = module.container_registry.container_registry_id
  subscription_id          = data.azurerm_client_config.current.subscription_id
  depends_on = [
    azurerm_resource_group.capz_ci,
    azurerm_storage_account.k8sprowstorage,
    module.container_registry
  ]
}

# Import Cluster API gallery module
module "cluster_api_gallery" {
  source              = "./cluster-api-gallery"
  resource_group_name = var.resource_group_name
  location            = var.location
  depends_on          = module.role_assignments
}

# Import CAPZ monitoring module
module "capz_monitoring" {
  source              = "./capz-monitoring"
  resource_group_name = var.resource_group_name
  location            = var.location
  subscription_id     = data.azurerm_client_config.current.subscription_id
}
