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

# solution admin user from GCVE
# xref: https://cloud.google.com/vmware-engine/docs/private-clouds/howto-elevate-privilege
variable "vsphere_user" {
  type    = string
}

variable "vsphere_password" {
  type = string
}

variable "vsphere_server" {
  type = string
}
# NSX-T user from GCVE dashboard
# xref: http://console.cloud.google.com/vmwareengine/privateclouds/us-central1-a/k8s-gcp-gcve-pc/management-appliances?project=broadcom-451918
variable "nsxt_user" {
  type = string
}

variable "nsxt_password" {
  type = string
}


variable "nsxt_server" {
  type = string
}

# This DNS Server was created by GCVE and can be found in GCVE's summary page.
# xref: https://console.cloud.google.com/vmwareengine/privateclouds/us-central1-a/k8s-gcp-gcve-pc/management-appliances?project=broadcom-451918
variable "gcve_dns_server" {
  type = string
  default = "192.168.30.234"
}

# This is the name of the Datacenter created by GCVE 
variable "vsphere_datacenter" {
  type = string
  default = "Datacenter"
}

# This is the name of the VMware Engine Private Cloud created via ../vmware-engine.tf
variable "vsphere_cluster" {
  type = string
  default = "k8s-gcve-cluster"
}

# This is the name of the Datastore created by GCVE 
variable "vsphere_datastorename" {
  type = string
  default = "vsanDatastore"
}

# This is the name of the Network which will be created in NSX-T
variable "vsphere_network_name" {
  type    = string
  default = "k8s-ci"
}

# This is the name of the IAM group specific to prow CI and created via scripts/ensure-users-groups.sh
variable "gcp_gcve_iam_group" {
  type = string
  default = "GVE.LOCAL\\prow-ci-group"
}

# This is the number of projects to be created in vSphere.
# It should match the number of boskos projects.
variable "gcp_gcve_nr_projects" {
  type    = number
  default = 40
}
