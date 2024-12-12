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

module "prow_network" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  version             = "0.6.0"
  name                = "vnet-${azurerm_resource_group.rg.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.52.0.0/16"]
  subnets = {
    "prow_build_aks" = {
      name                                      = "snet-${azurerm_resource_group.rg.name}"
      address_prefixes                          = ["10.52.1.0/24"]
      service_endpoints                         = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
      private_endpoint_network_policies_enabled = false
    }
  }

  tags             = var.common_tags
  enable_telemetry = false
}

module "private_dns_zones" {
  source                          = "Azure/avm-ptn-network-private-link-private-dns-zones/azurerm"
  version                         = "0.4.0"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  resource_group_creation_enabled = false
  tags                            = var.common_tags
  enable_telemetry                = false
  private_link_private_dns_zones = {
    azure_aks_mgmt = {
      zone_name = "privatelink.{regionName}.azmk8s.io"
    }
    azure_acr_data = {
      zone_name = "{regionName}.data.privatelink.azurecr.io"
    }
    azure_site_recovery = {
      zone_name = "privatelink.siterecovery.windowsazure.com"
    }
    azure_monitor = {
      zone_name = "privatelink.monitor.azure.com"
    }
    azure_log_analytics = {
      zone_name = "privatelink.oms.opinsights.azure.com"
    }
    azure_log_analytics_data = {
      zone_name = "privatelink.ods.opinsights.azure.com"
    }
    azure_monitor_agent = {
      zone_name = "privatelink.agentsvc.azure-automation.net"
    }
  }

  virtual_network_resource_ids_to_link_to = {
    "vnet_prow_build_aks" = {
      vnet_resource_id = module.prow_network.resource_id
    }
  }
}
