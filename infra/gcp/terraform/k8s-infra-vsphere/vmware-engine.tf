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

# resource "google_vmwareengine_private_cloud" "vsphere-cluster" {
#   location    = "us-central1"
#   name        = "sample-pc"
#   description = "vSphere Cluster for CI."
#   # TODO: type TIME_LIMITED is for the timely limitted 1 node_count. Change to `STANDARD`.
#   type        = "TIME_LIMITED"
#   network_config {
#     management_cidr       = "192.168.30.0/24"
#     vmware_engine_network = google_vmwareengine_network.cluster-nw.id
#   }

#   management_cluster {
#     cluster_id = "vsphere-ci-cluster"
#     node_type_configs {
#       node_type_id = "standard-72"
#       # TODO: node_count 1 is for the TIME_LIMITED version. Change to `3`.
#       node_count   = 1
#     }
#   }
# }

# resource "google_vmwareengine_network" "vsphere-network" {
#   name        = "vsphere-network"
#   type        = "STANDARD"
#   # TODO: check if this needs to be set to `global` (it should according tf docs).
#   location    = "us-central1"
#   description = "network for vSphere CI."
# }
