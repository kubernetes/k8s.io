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

variable "vsphere_user" {
  type    = string
}

variable "vsphere_password" {
  type = string
}

variable "vsphere_server" {
  type = string
}

variable "nsxt_server" {
  type = string
}

variable "nsxt_user" {
  type = string
}

variable "nsxt_password" {
  type = string
}

# This DNS Server was created via GCVE and can be found in GCVE's summary page.
variable "gcve_dns_server" {
  type = string
  default = "192.168.30.234"
}

variable "vsphere_datacenter" {
  type = string
  default = "Datacenter"
}

variable "vsphere_cluster" {
  type = string
  default = "k8s-gcve-cluster"
}

variable "vsphere_datastorename" {
  type = string
  default = "vsanDatastore"
}

variable "vsphere_network_name" {
  type    = string
  default = "k8s-ci"
}

# Variables specific to cluster-api-provider-vsphere

variable "gcp_gcve_iam_group" {
  type = string
  default = "prow-ci-group"
}

variable "gcp_gcve_nr_projects" {
  type    = number
  default = 40
}
