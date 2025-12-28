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
  source        = "Azure/avm-res-network-virtualnetwork/azurerm"
  version       = "0.16.0"
  name          = "vnet-${azurerm_resource_group.rg.name}"
  parent_id     = azurerm_resource_group.rg.id
  location      = azurerm_resource_group.rg.location
  address_space = ["10.52.0.0/16", "fd00:d2cc:d945::/48"]
  subnets = {
    "prow_build_aks" = {
      name                                      = "snet-${azurerm_resource_group.rg.name}"
      address_prefixes                          = ["10.52.0.0/22", "fd00:d2cc:d945:1::/64"]
      service_endpoints                         = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
      private_endpoint_network_policies_enabled = false
    }
  }

  tags             = var.common_tags
  enable_telemetry = false
}

module "private_dns_zones" {
  source           = "Azure/avm-ptn-network-private-link-private-dns-zones/azurerm"
  version          = "0.23.0"
  parent_id        = azurerm_resource_group.rg.id
  location         = azurerm_resource_group.rg.location
  tags             = var.common_tags
  enable_telemetry = false
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

  virtual_network_link_additional_virtual_networks = {
    "vnet_prow_build_aks" = {
      virtual_network_resource_id = module.prow_network.resource_id
    }
  }
}
