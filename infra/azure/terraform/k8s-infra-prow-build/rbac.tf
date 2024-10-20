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

resource "azurerm_role_assignment" "admin" {
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = module.prow_build.aks_id
  principal_id         = data.azurerm_client_config.current.object_id # Me
}

# Control Plane

resource "azurerm_role_assignment" "control_plane_mi" {
  role_definition_name = "Managed Identity Operator"
  scope                = azurerm_resource_group.rg.id
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Kubelet
resource "azurerm_role_assignment" "kubelet_mi_operator" {
  role_definition_name = "Managed Identity Operator"
  scope                = azurerm_resource_group.rg.id
  principal_id         = azurerm_user_assigned_identity.aks_kubelet_identity.principal_id
}
