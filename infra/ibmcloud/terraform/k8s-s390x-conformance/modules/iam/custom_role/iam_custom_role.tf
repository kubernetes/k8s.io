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

resource "ibm_iam_custom_role" "vpc_build_cluster" {
  name         = "VPCBuildClusterRole"
  display_name = "VPCBuildClusterRole"
  service      = "is"
  actions = [
    "is.vpc.vpc.read",
    "is.vpc.vpc.create",
    "is.vpc.vpc.update",
    "is.vpc.vpc.list",
    "is.vpc.vpc.delete",
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

resource "ibm_iam_custom_role" "janitor_vpc" {
  name         = "JanitorVPCRole"
  display_name = "JanitorVPCRole"
  service      = "is"
  actions = [
    "is.instance.instance.delete",
    "is.subnet.subnet.delete",
    "is.security-group.security-group.delete",
    "is.floating-ip.floating-ip.delete",
    "is.vpc.vpc.read",
    "is.subnet.subnet.read",
    "is.security-group.security-group.read",
    "is.instance.instance.read",
    "resource-controller.instance.retrieve",
    "resource-controller.group.retrieve"
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
