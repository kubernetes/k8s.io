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

# Create the "cluster-api-gallery" resource group
resource "azurerm_resource_group" "cluster-api-gallery" {
  location = var.location
  name     = var.resource_group_name
  tags = {
    DO-NOT-DELETE     = "UpstreamInfra"
    creationTimestamp = "2024-10-24T00:00:00Z"
  }
}

# Create the shared image gallery with community permissions
resource "azurerm_shared_image_gallery" "community_gallery" {
  description         = "Shared image gallery for Cluster API Provider Azure"
  location            = var.location
  name                = "community_gallery"
  resource_group_name = "cluster-api-gallery"
  tags = {
    creationTimestamp = "2024-10-24T00:00:00Z"
    jobName           = "image-builder-sig-ubuntu-2404"
  }
  sharing {
    permission = "Community"
    community_gallery {
      eula            = "https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/LICENSE"
      prefix          = "ClusterAPI"
      publisher_email = "az-k8s-up-infra@microsoft.com"
      publisher_uri   = "https://github.com/kubernetes-sigs/cluster-api-provider-azure"
    }
  }
  depends_on = [
    azurerm_resource_group.cluster-api-gallery,
  ]
}

# Create the user-assigned identity for publishing with ADO pipelines
resource "azurerm_user_assigned_identity" "pipelines_user_identity" {
  location            = var.location
  name                = "ado-pipeline-mi"
  resource_group_name = var.resource_group_name
  tags = {
    DO-NOT-DELETE     = "UpstreamInfra"
    creationTimestamp = "2024-10-24T00:00:00Z"
  }
  depends_on = [
    azurerm_resource_group.cluster-api-gallery,
  ]
}
