/*
Copyright 2025 The Kubernetes Authors.

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

resource "ibm_pi_workspace" "powervs_service_instance" {
  pi_name              = var.pi_workspace_name
  pi_datacenter        = var.datacenter
  pi_resource_group_id = var.resource_group_id
}

data "ibm_pi_catalog_images" "catalog_images" {
  pi_cloud_instance_id = ibm_pi_workspace.powervs_service_instance.id
}

locals {
  catalog_image = [for x in data.ibm_pi_catalog_images.catalog_images.images : x if x.name == var.image_name]
}

# Copy image from catalog if not in the project and present in catalog
resource "ibm_pi_image" "image" {
  pi_image_id          = local.catalog_image[0].image_id
  pi_cloud_instance_id = ibm_pi_workspace.powervs_service_instance.id
}
