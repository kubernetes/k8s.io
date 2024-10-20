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

module "prow_build" {
  source                    = "Azure/aks/azurerm"
  version                   = "9.1.0"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  sku_tier                  = "Standard"
  automatic_channel_upgrade = "patch"
  kubernetes_version        = "1.30"
  prefix                    = "k8s-infra"

  role_based_access_control_enabled = true
  workload_identity_enabled         = true
  oidc_issuer_enabled               = true
  rbac_aad                          = true
  rbac_aad_managed                  = true
  local_account_disabled            = false

  identity_type = "UserAssigned"
  identity_ids  = [azurerm_user_assigned_identity.aks_identity.id]

  msi_auth_for_monitoring_enabled = true

  kubelet_identity = {
    client_id                 = azurerm_user_assigned_identity.aks_kubelet_identity.client_id
    object_id                 = azurerm_user_assigned_identity.aks_kubelet_identity.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_kubelet_identity.id
  }

  ebpf_data_plane     = "cilium"
  network_plugin_mode = "overlay"
  network_plugin      = "azure"
  network_policy      = "cilium"

  enable_auto_scaling = true
  node_resource_group = "MC_${local.prefix}-prow-build-${azurerm_resource_group.rg.location}-aks-rg"

  auto_scaler_profile_enabled                     = true
  auto_scaler_profile_balance_similar_node_groups = true
  auto_scaler_profile_max_unready_nodes           = 1

  agents_pool_name             = "system"
  agents_min_count             = 3
  agents_max_count             = 9
  agents_max_pods              = 110
  agents_type                  = "VirtualMachineScaleSets"
  agents_availability_zones    = ["1", "3"]
  os_sku                       = "AzureLinux"
  agents_size                  = "Standard_D4ds_v5"
  only_critical_addons_enabled = true
  temporary_name_for_rotation  = "tmpnodepool1"
  agents_tags                  = var.common_tags
  vnet_subnet_id               = module.prow_network.subnets.prow_build_aks.resource_id

  storage_profile_enabled             = true
  storage_profile_blob_driver_enabled = false
  storage_profile_file_driver_enabled = false

  maintenance_window_auto_upgrade = {
    frequency   = "Weekly"
    day_of_week = "Wednesday"
    interval    = 1
    duration    = 8
    utc_offset  = "+00:00"
    start_time  = "10:00" # UTC
  }

  maintenance_window_node_os = {
    frequency   = "Weekly"
    day_of_week = "Wednesday"
    interval    = 1
    duration    = 8
    utc_offset  = "+00:00"
    start_time  = "18:00" # UTC
  }

  maintenance_window = {
    allowed = [
      {
        day   = "Wednesday",
        hours = [8, 23]
      },
    ]
  }

  node_pools = {
    pool1 = {
      name                = "pool1"
      vm_size             = "Standard_E8ds_v5"
      enable_auto_scaling = true
      kubelet_disk_type   = "OS"
      min_count           = 3
      max_count           = 200
      os_disk_type        = "Ephemeral"
      os_disk_size_gb     = 100
      os_sku              = "Ubuntu"

      upgrade_settings = {
        max_surge                     = "33%"
        drain_timeout_in_minutes      = 90
        node_soak_duration_in_minutes = 1
      }
    }
  }

  depends_on = [module.prow_network]
}
