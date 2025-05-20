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

# Grant read-only access to the datacenter.
# Permissions will later be granted on lower placed resource pools.
## /<datacenter>

# Deny access recursively to the prow resource pool to restrict the above recursive read-only rule.
# Permissions will later be granted on lower placed resource pools.
## /<datacenter>/host/<cluster>/Resources/prow

resource "vsphere_entity_permissions" "permissions_prow_resource_pool" {
  entity_id   = vsphere_resource_pool.prow.id
  entity_type = "ResourcePool"
  permissions {
    user_or_group = var.gcp_gcve_iam_group
    propagate     = true
    is_group      = true
    role_id       = vsphere_role.vsphere-ci.id
  }
}


resource "vsphere_entity_permissions" "permissions_prow_folder" {
  entity_id   = vsphere_folder.prow.id
  entity_type = "Folder"
  permissions {
    user_or_group = var.gcp_gcve_iam_group
    propagate     = true
    is_group      = true
    role_id       = vsphere_role.vsphere-ci.id
  }
}

# Grant access on the network.
## /<datacenter>/network/<network>

# resource "vsphere_entity_permissions" "permissions_network" {
#   entity_id   = data.vsphere_network.network.id
#   entity_type = "Network"
#   permissions {
#     user_or_group = var.gcp_gcve_iam_group
#     propagate     = true
#     is_group      = true
#     role_id       = vsphere_role.vsphere-ci.id
#   }
# }

# TODO(chrischdi): we propably also have to add ReadOnly to the /<datacenter>/network/<hostswitch>


# Grant read-only access to the templates vm directory.
## /<datacenter>/vm/prow/templates

resource "vsphere_entity_permissions" "permissions_templates_directory" {
  entity_id   = vsphere_folder.templates.id
  entity_type = "ClusterComputeResource"
  permissions {
    user_or_group = var.gcp_gcve_iam_group
    propagate     = true
    is_group      = true
    role_id       = vsphere_role.vsphere-ci.id
  }
}
