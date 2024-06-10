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

variable "vsphere_user" {
  type    = string
  default = "administrator@vsphere.local"
}

variable "vsphere_password" {
  type = string
}

variable "vsphere_server" {
  type = string
}

variable "vsphere_datacenter" {
  type = string
}

variable "vsphere_cluster" {
  type = string
}

variable "vsphere_datastorename" {
  type = string
}

variable "vsphere_network_name" {
  type    = string
  default = "VM Network"
}

# Variables specific to cluster-api-provider-vsphere

variable "cluster_api_provider_vsphere_iam_group" {
  type = string
}

variable "cluster_api_provider_vsphere_nr_projects" {
  type    = number
  default = 5
}

# Variables specific to cloud-provider-vsphere

variable "cloud_provider_vsphere_iam_group" {
  type = string
}

variable "cloud_provider_vsphere_nr_projects" {
  type    = number
  default = 5
}

# Variables specific to image-builder

variable "image_builder_iam_group" {
  type = string
}

variable "image_builder_nr_projects" {
  type    = number
  default = 5
}

# Variables specific to janitor

variable "vsphere_janitor_iam_group" {
  type = string
}
