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

resource "vsphere_resource_pool" "prow" {
  name                    = "prow"
  parent_resource_pool_id = data.vsphere_compute_cluster.compute_cluster.resource_pool_id
  scale_descendants_shares = "disabled"
}

resource "vsphere_resource_pool" "templates" {
  name                    = "templates"
  parent_resource_pool_id = vsphere_resource_pool.prow.id
  scale_descendants_shares = "disabled"
}
