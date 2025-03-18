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

locals {
  image_name = "CentOS-Stream-9"
}

resource "ibm_pi_workspace" "build_cluster" {
  pi_name              = "k8s-powervs-build-cluster-osa21"
  pi_datacenter        = "osa21"
  pi_resource_group_id = module.resource_group.k8s_rg_id
}

data "ibm_pi_catalog_images" "catalog_images" {
  pi_cloud_instance_id = ibm_pi_workspace.build_cluster.id
}

locals {
  catalog_image = [for x in data.ibm_pi_catalog_images.catalog_images.images : x if x.name == local.image_name]
}

# Copy image from catalog if not in the project and present in catalog
resource "ibm_pi_image" "image" {
  pi_image_id          = local.catalog_image[0].image_id
  pi_cloud_instance_id = ibm_pi_workspace.build_cluster.id
}

resource "ibm_pi_key" "sshkey" {
  pi_key_name          = "k8s-sshkey"
  pi_ssh_key           = module.secrets_manager.k8s_powervs_ssh_public_key
  pi_cloud_instance_id = ibm_pi_workspace.build_cluster.id
}
