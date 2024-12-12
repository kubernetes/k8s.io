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

locals {
  prefix               = "k8s-infra"
  log_analytics_tables = ["AKSAudit", "AKSAuditAdmin", "AKSControlPlane", "ContainerLogV2"]
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.1"
  suffix  = ["k8s-infra-prow-build"]
}

module "azure_region" {
  source  = "claranet/regions/azurerm"
  version = "~> 7.2"

  azure_region = var.default_region
}

resource "azurerm_resource_group" "rg" {
  name     = module.naming.resource_group.name
  location = module.azure_region.location
  tags     = var.common_tags

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags["DateCreated"]
    ]
  }
}

