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
  gcp_gcve_project_name = "k8s-infra-e2e-gcp-gcve-project"
}

## create the projects (resource pool, folder, assign permissions per resource pool and folder)
module "gcp-gcve-projects" {
  source = "./modules/gcp-gcve-project"

  project_name             = local.gcp_gcve_project_name
  group                    = var.gcp_gcve_iam_group
  nr_projects              = var.gcp_gcve_nr_projects
  role_id                  = vsphere_role.vsphere-ci.id
  vsphere_datacenter_id    = data.vsphere_datacenter.datacenter.id
  vsphere_folder_path      = vsphere_folder.prow.path
  vsphere_resource_pool_id = vsphere_resource_pool.prow.id

  depends_on = [vsphere_role.vsphere-ci, vsphere_resource_pool.prow]
}
