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

resource "ibm_iam_access_group" "vpc_build_cluster" {
  name        = "vpc-build-cluster-access"
  description = "Access group with the necessary permissions for provisioning VPC-based build clusters."
}

resource "ibm_iam_access_group_policy" "vpc_build_cluster" {
  access_group_id = ibm_iam_access_group.vpc_build_cluster.id
  roles           = ["VPCBuildClusterRole"]

  resources {
    service           = "is"
    resource_group_id = var.resource_group_id
  }
}

resource "ibm_iam_access_group" "janitor" {
  name        = "janitor-access"
  description = "Access group with the necessary permissions for the Boskos Janitor."
}

resource "ibm_iam_access_group_policy" "janitor_vpc" {
  access_group_id = ibm_iam_access_group.janitor.id
  roles           = ["JanitorVPCRole"]

  resources {
    service           = "is"
    resource_group_id = var.resource_group_id
  }
}

resource "ibm_iam_access_group" "secret_rotator" {
  name        = "secret-rotator"
  description = "Access group with the necessary permissions for secret-manager(rotator)."
}

resource "ibm_iam_access_group_policy" "secret_rotator" {
  access_group_id = ibm_iam_access_group.secret_rotator.id
  roles           = ["SecretRotator"]

  resources {
    service           = "secrets-manager"
    resource_group_id = var.resource_group_id
  }
}
