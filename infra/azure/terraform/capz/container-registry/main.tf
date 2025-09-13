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

resource "azurerm_container_registry" "capzci_registry" {
  name                   = "capzcicommunity"
  location               = var.location
  resource_group_name    = var.resource_group_name
  sku                    = "Premium"
  anonymous_pull_enabled = true

  retention_policy_in_days = 7

  tags = {
    RetentionPolicy = "7days"
  }
}

resource "azurerm_management_lock" "registry_lock" {
  name       = "DO-NOT_DELETE"
  scope      = azurerm_container_registry.capzci_registry.id
  lock_level = "CanNotDelete"
  notes      = "Contact Capz"
}

resource "azurerm_container_registry_cache_rule" "calico_apiserver" {
  name                  = "calico-apiserver-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/apiserver"
  target_repo           = "calico/apiserver"
}

resource "azurerm_container_registry_cache_rule" "calico_cni" {
  name                  = "calico-cni-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/cni"
  target_repo           = "calico/cni"
}

resource "azurerm_container_registry_cache_rule" "calico_cni_windows" {
  name                  = "calico-cni-windows-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/cni-windows"
  target_repo           = "calico/cni-windows"
}

resource "azurerm_container_registry_cache_rule" "calico_csi" {
  name                  = "calico-csi-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/csi"
  target_repo           = "calico/csi"
}

resource "azurerm_container_registry_cache_rule" "calico_ctl" {
  name                  = "calico-ctl-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/ctl"
  target_repo           = "calico/ctl"
}

resource "azurerm_container_registry_cache_rule" "calico_kube_controllers" {
  name                  = "calico-kube-controllers-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/kube-controllers"
  target_repo           = "calico/kube-controllers"
}

resource "azurerm_container_registry_cache_rule" "calico_node" {
  name                  = "calico-node-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/node"
  target_repo           = "calico/node"
}

resource "azurerm_container_registry_cache_rule" "calico_node_driver_registrar" {
  name                  = "calico-node-driver-registrar-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/node-driver-registrar"
  target_repo           = "calico/node-driver-registrar"
}

resource "azurerm_container_registry_cache_rule" "calico_node_windows" {
  name                  = "calico-node-windows-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/node-windows"
  target_repo           = "calico/node-windows"
}

resource "azurerm_container_registry_cache_rule" "calico_pod2daemon_flexvol" {
  name                  = "calico-pod2daemon-flexvol-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/pod2daemon-flexvol"
  target_repo           = "calico/pod2daemon-flexvol"
}

resource "azurerm_container_registry_cache_rule" "calico_typha" {
  name                  = "calico-typha-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/calico/typha"
  target_repo           = "calico/typha"
}

resource "azurerm_container_registry_cache_rule" "tigera_operator" {
  name                  = "tigera-operator-cache"
  container_registry_id = azurerm_container_registry.capzci_registry.id
  source_repo           = "quay.io/tigera/operator"
  target_repo           = "tigera/operator"
}

resource "azurerm_container_registry_task" "registry_task" {
  container_registry_id = azurerm_container_registry.capzci_registry.id
  name                  = "midnight_capz_purge"
  agent_setting {
    cpu = 2
  }
  base_image_trigger {
    name                        = "defaultBaseimageTriggerName"
    type                        = "Runtime"
    update_trigger_payload_type = "Default"
  }
  encoded_step {
    task_content = base64encode(<<EOF
version: v1.1.0
steps:
  - cmd: acr purge --filter azdisk:* --filter azure-cloud-controller-manager:* --filter azure-cloud-node-manager-arm64:* --filter azure-cloud-node-manager:* --filter cluster-api-azure:* --ago 1d --untagged
    disableWorkingDirectoryOverride: true
    timeout: 3600
EOF
    )
  }
  platform {
    architecture = "amd64"
    os           = "Linux"
  }
  timer_trigger {
    name     = "t1"
    schedule = "0 0 * * *"
  }
}

output "container_registry_id" {
  value = azurerm_container_registry.capzci_registry.id
}

resource "azurerm_container_registry" "e2eprivate_registry" {
  name                = "e2eprivatecommunity"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Premium"

  retention_policy_in_days = 7

  tags = {
    RetentionPolicy = "7days"
  }
}

resource "azurerm_management_lock" "e2eregistry_lock" {
  name       = "DO-NOT_DELETE"
  scope      = azurerm_container_registry.e2eprivate_registry.id
  lock_level = "CanNotDelete"
  notes      = "Contact Capz"
}

output "e2eprivate_registry_id" {
  value = azurerm_container_registry.e2eprivate_registry.id
}
