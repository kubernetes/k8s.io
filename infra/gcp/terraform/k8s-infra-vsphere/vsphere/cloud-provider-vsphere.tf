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
  cloud_provider_vsphere_project_name = "cloud-provider-vsphere"
  cloud_provider_vsphere_group = "vsphere.local\\prow-${local.cloud_provider_vsphere_project_name}-users"
}

module "cloud-provider-vsphere" {
  source = "./modules/vsphere-project"

  project_name = local.cloud_provider_vsphere_project_name
  group = local.cloud_provider_vsphere_group
  nr_projects = 5
  role_id = vsphere_role.capv-ci.id
  vsphere_datacenter_id = data.vsphere_datacenter.datacenter.id
  vsphere_folder_path = vsphere_folder.prow.path
  vsphere_resource_pool_id = vsphere_resource_pool.prow.id
}