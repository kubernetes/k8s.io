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

data "vsphere_datacenter" "datacenter" {
  name = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "compute_cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastorename
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_role" "read-only" {
  label = "Read-only"
}

data "vsphere_role" "no-access" {
  label = "No access"
}

# data "vsphere_network" "network" {
#   name          = var.vsphere_network_name
#   datacenter_id = data.vsphere_datacenter.datacenter.id
# }

data "vsphere_folder" "global" {
  path = "/"
}