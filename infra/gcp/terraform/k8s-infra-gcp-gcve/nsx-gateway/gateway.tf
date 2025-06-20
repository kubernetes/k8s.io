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

# Read the secret from Secret Manager which contains the wireguard server configuration. 
data "google_secret_manager_secret_version_access" "wireguard-config" {
  project      = var.project_id
  secret = "nsx-gateway-vm-wireguard-config"
}

resource "vsphere_virtual_machine" "gateway_vm" {
  name             = "gateway-vm"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = 2
  memory           = 2048
  guest_id         = "ubuntu64Guest"
  network_interface {
    network_id = data.vsphere_network.network.id
  }
  disk {
    label = "Hard Disk 1"
    size  = 20
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }
  extra_config = {
    "guestinfo.metadata" = base64encode(file("${path.module}/metadata.yaml"))
    "guestinfo.userdata" = base64encode(templatefile(
      "${path.module}/cloud-config.yaml.tftpl",
      { 
        wg0 = base64encode(data.google_secret_manager_secret_version_access.wireguard-config.secret_data)
        ssh_public_key = var.ssh_public_key
      }
    ))
    "guestinfo.metadata.encoding" ="base64"
    "guestinfo.userdata.encoding" ="base64"
  }
}

data "vsphere_virtual_machine" "template" {
  name          = "/Datacenter/vm/prow/templates/ubuntu-2404-kube-v1.33.0"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_datacenter" "datacenter" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastorename
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}