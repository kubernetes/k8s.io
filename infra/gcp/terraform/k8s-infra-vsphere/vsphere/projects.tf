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

# cloud-provider-vsphere

locals {
  cloud_provider_vsphere_project_name = "cloud-provider-vsphere"
}

# ## create global permissions to read cluster, datastore, host information etc.
# module "cloud-provider-vsphere-iam" {
#   source = "./modules/vsphere-project-iam"

#   group = var.cloud_provider_vsphere_iam_group
#   vsphere_role_id = vsphere_role.vsphere-ci.id
#   vsphere_datacenter_id = data.vsphere_datacenter.datacenter.id
#   vsphere_datastore_id = data.vsphere_datastore.datastore.id
#   vsphere_compute_cluster_id = data.vsphere_compute_cluster.compute_cluster.id
#   vsphere_resource_pool_id = vsphere_resource_pool.prow.id
#   vsphere_network_name = var.vsphere_network_name

#   depends_on = [ vsphere_role.vsphere-ci, vsphere_resource_pool.prow ]
# }

## create the projects (resource pool, folder, assign permissions per resource pool and folder)
module "cloud-provider-vsphere" {
  source = "./modules/vsphere-project"

  project_name = local.cloud_provider_vsphere_project_name
  group = var.cloud_provider_vsphere_iam_group
  nr_projects = var.cloud_provider_vsphere_nr_projects
  role_id = vsphere_role.vsphere-ci.id
  vsphere_datacenter_id = data.vsphere_datacenter.datacenter.id
  vsphere_folder_path = vsphere_folder.prow.path
  vsphere_resource_pool_id = vsphere_resource_pool.prow.id

  depends_on = [ vsphere_role.vsphere-ci, vsphere_resource_pool.prow ]
}


# cluster-api-provider-vsphere

locals {
  cluster_api_provider_vsphere_project_name = "cluster-api-provider-vsphere"
}

# ## create global permissions to read cluster, datastore, host information etc.
# module "cluster-api-provider-vsphere-iam" {
#   source = "./modules/vsphere-project-iam"

#   group = var.cluster_api_provider_vsphere_iam_group
#   vsphere_role_id = vsphere_role.vsphere-ci.id
#   vsphere_datacenter_id = data.vsphere_datacenter.datacenter.id
#   vsphere_datastore_id = data.vsphere_datastore.datastore.id
#   vsphere_compute_cluster_id = data.vsphere_compute_cluster.compute_cluster.id
#   vsphere_resource_pool_id = vsphere_resource_pool.prow.id
#   vsphere_network_name = var.vsphere_network_name

#   depends_on = [ vsphere_role.vsphere-ci, vsphere_resource_pool.prow ]
# }

## create the projects (resource pool, folder, assign permissions per resource pool and folder)
module "cluster-api-provider-vsphere" {
  source = "./modules/vsphere-project"

  project_name = local.cluster_api_provider_vsphere_project_name
  group = var.cluster_api_provider_vsphere_iam_group
  nr_projects = var.cluster_api_provider_vsphere_nr_projects
  role_id = vsphere_role.vsphere-ci.id
  vsphere_datacenter_id = data.vsphere_datacenter.datacenter.id
  vsphere_folder_path = vsphere_folder.prow.path
  vsphere_resource_pool_id = vsphere_resource_pool.prow.id
  
  depends_on = [ vsphere_role.vsphere-ci, vsphere_resource_pool.prow]
}

# image-builder

locals {
  image_builder_project_name = "image-builder"
}

# ## create global permissions to read cluster, datastore, host information etc.
# module "image-builder-iam" {
#   source = "./modules/vsphere-project-iam"

#   group = var.image_builder_iam_group
#   vsphere_role_id = vsphere_role.image-builder-ci.id
#   vsphere_datacenter_id = data.vsphere_datacenter.datacenter.id
#   vsphere_datastore_id = data.vsphere_datastore.datastore.id
#   vsphere_compute_cluster_id = data.vsphere_compute_cluster.compute_cluster.id
#   vsphere_resource_pool_id = vsphere_resource_pool.prow.id
#   vsphere_network_name = var.vsphere_network_name

#   depends_on = [ vsphere_role.image-builder-ci, vsphere_resource_pool.prow ]
# }

## create the projects (resource pool, folder, assign permissions per resource pool and folder)
module "image-builder" {
  source = "./modules/vsphere-project"

  project_name = local.image_builder_project_name
  group = var.image_builder_iam_group
  nr_projects = var.image_builder_nr_projects
  role_id = vsphere_role.image-builder-ci.id
  vsphere_datacenter_id = data.vsphere_datacenter.datacenter.id
  vsphere_folder_path = vsphere_folder.prow.path
  vsphere_resource_pool_id = vsphere_resource_pool.prow.id
  
  depends_on = [ vsphere_role.image-builder-ci, vsphere_resource_pool.prow ]
}
