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

// Adds tags required for failure domain tests

resource "vsphere_tag_category" "category_k8s_region" {
  name        = "k8s-region"
  cardinality = "MULTIPLE"
  description = "Managed by Terraform"

  associable_types = [
    "Datacenter",
  ]
}

resource "vsphere_tag_category" "category_k8s_zone" {
  name        = "k8s-zone"
  cardinality = "MULTIPLE"
  description = "Managed by Terraform"

  associable_types = [
    "ClusterComputeResource",
  ]
}

resource "vsphere_tag" "tag_k8s_region" {
  name        = var.vsphere_datacenter
  category_id = "${vsphere_tag_category.category_k8s_region.id}"
  description = "Managed by Terraform"
}

resource "vsphere_tag" "tag_k8s_zone" {
  name        = var.vsphere_cluster
  category_id = "${vsphere_tag_category.category_k8s_zone.id}"
  description = "Managed by Terraform"
}
