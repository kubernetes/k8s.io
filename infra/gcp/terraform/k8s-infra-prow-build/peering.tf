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

resource "google_vmwareengine_network_peering" "gvce_peering" {
  name                                = "peer-with-gcve-project"
  peer_network                        = "projects/k8s-infra-prow-build/global/networks/default"
  project                             = module.project.project_id
  peer_network_type                   = "STANDARD"
  vmware_engine_network               = "projects/broadcom-451918/locations/global/vmwareEngineNetworks/k8s-gcp-gcve-network"
  export_custom_routes_with_public_ip = true
  import_custom_routes_with_public_ip = true
  lifecycle {
    ignore_changes = [
      # https://github.com/hashicorp/terraform-provider-google/issues/17817
      export_custom_routes_with_public_ip,
      import_custom_routes_with_public_ip,
    ]
  }
}
