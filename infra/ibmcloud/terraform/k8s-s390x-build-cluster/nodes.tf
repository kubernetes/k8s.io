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
  control_plane_nodes = {
    for idx in range(1, var.control_plane_node_count + 1) :
    "${idx}" => {
      profile = var.control_plane_node_profile
      boot_volume = {
        size = var.control_plane_boot_volume_size
      }
    }
  }

  compute_nodes = {
    for idx in range(1, var.compute_node_count + 1) :
    "${idx}" => {
      profile = var.compute_node_profile
      boot_volume = {
        size = var.compute_boot_volume_size
      }
    }
  }
}
resource "ibm_is_ssh_key" "k8s_ssh_key" {
  name           = "k8s-s390x-ssh-key"
  public_key     = data.ibm_sm_arbitrary_secret.ssh_public_key.payload
  resource_group = data.ibm_resource_group.resource_group.id
}

resource "ibm_is_instance" "control_plane" {
  for_each = local.control_plane_nodes

  name           = "control-plane-s390x-${each.key}"
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = var.zone
  profile        = each.value.profile
  image          = data.ibm_is_image.os_image.id
  keys           = [ibm_is_ssh_key.k8s_ssh_key.id]
  resource_group = data.ibm_resource_group.resource_group.id

  primary_network_interface {
    subnet          = data.ibm_is_subnet.subnet.id
    security_groups = [data.ibm_is_security_group.control_plane_sg.id]
  }

  boot_volume {
    name = "boot-vol-cp-s390x-${each.key}"
    size = each.value.boot_volume.size
  }
}

resource "ibm_is_instance" "compute" {
  for_each = local.compute_nodes

  name           = "worker-s390x-${each.key}"
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = var.zone
  profile        = each.value.profile
  image          = data.ibm_is_image.os_image.id
  keys           = [ibm_is_ssh_key.k8s_ssh_key.id]
  resource_group = data.ibm_resource_group.resource_group.id

  primary_network_interface {
    subnet          = data.ibm_is_subnet.subnet.id
    security_groups = [data.ibm_is_security_group.worker_sg.id]
  }

  boot_volume {
    name = "boot-vol-worker-s390x-${each.key}"
    size = each.value.boot_volume.size
  }
}
