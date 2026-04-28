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

resource "ibm_iam_custom_role" "pvs" {
  name         = "PVSRole"
  display_name = "PVSRole"
  service      = "power-iaas.workspace"
  actions = [
    "power-iaas.network.create",
    "power-iaas.network.delete",
    "power-iaas.pvm-instance.create",
    "power-iaas.pvm-instance.delete",
    "power-iaas.cloud-instance-image.list",
    "power-iaas.cloud-instance-image.read",
    "power-iaas.cloud-instance.read",
  ]
}

resource "ibm_iam_custom_role" "sm" {
  name         = "SMRead"
  display_name = "SMRead"
  service      = "secrets-manager"
  actions = [
    "secrets-manager.secrets.list",
    "secrets-manager.secret.read",
  ]
}

resource "ibm_iam_custom_role" "janitor_pvs" {
  name         = "JanitorPVSRole"
  display_name = "JanitorPVSRole"
  service      = "power-iaas.workspace"
  actions = [
    "power-iaas.dashboard.view",
    "power-iaas.cloud-instance.modify",
    "power-iaas.cloud-instance.read",
    "resource-controller.instance.retrieve",
    "resource-controller.group.retrieve",
    "global-search-tagging.resource.read",
  ]
}

resource "ibm_iam_custom_role" "secret_rotator" {
  name         = "SecretRotator"
  display_name = "SecretRotator"
  service      = "secrets-manager"
  actions = [
    "secrets-manager.secret-version.read",
    "secrets-manager.secret-version.create",
    "secrets-manager.secret.read",
    "secrets-manager.secret.rotate",
  ]
}
