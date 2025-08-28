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

locals {
  # reproduce the previous pattern seen in state:
  # "<first-10-of-rg>-<rg>-<first-6-of-subscription>"
  computed_dns_prefix = format("%s-%s-%s",
    substr(var.resource_group_name, 0, 10),
    var.resource_group_name,
    substr(var.subscription_id, 0, 6)
  )
}

# Create the "capz-monitoring" resource group
resource "azurerm_resource_group" "capz-monitoring" {
  location = var.location
  name     = var.resource_group_name
  tags = {
    DO-NOT-DELETE     = "contact capz"
  }
}

resource "azurerm_user_assigned_identity" "capz_monitoring_user_identity" {
  name                = "capz-monitoring-user-identity"
  location            = azurerm_resource_group.capz-monitoring.location
  resource_group_name = azurerm_resource_group.capz-monitoring.name
}

resource "azurerm_role_assignment" "monitoring_reader" {
  principal_id         = azurerm_user_assigned_identity.capz_monitoring_user_identity.principal_id
  role_definition_name = "Monitoring Reader"
  scope                = "/subscriptions/${var.subscription_id}"
  depends_on = [ azurerm_user_assigned_identity.capz_monitoring_user_identity ]
}

resource "azurerm_kubernetes_cluster" "capz-monitoring" {
  dns_prefix            = local.computed_dns_prefix
  location              = var.location
  name                  = var.resource_group_name
  resource_group_name   = var.resource_group_name
  tags = {
    DO-NOT-DELETE     = "contact capz"
    creationTimestamp = timestamp()
  }
  depends_on = [
    azurerm_resource_group.capz-monitoring,
    azurerm_user_assigned_identity.capz_monitoring_user_identity,
  ]
  kubelet_identity {
    user_assigned_identity_id = azurerm_user_assigned_identity.capz_monitoring_user_identity.id
    client_id                 = azurerm_user_assigned_identity.capz_monitoring_user_identity.client_id
    object_id                 = azurerm_user_assigned_identity.capz_monitoring_user_identity.principal_id
  }
  identity {
    type                     = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.capz_monitoring_user_identity.id
    ]
  }
  default_node_pool {
    name       = "nodepool1"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  lifecycle {
    ignore_changes = [
      "linux_profile",
    ]
  }
}
