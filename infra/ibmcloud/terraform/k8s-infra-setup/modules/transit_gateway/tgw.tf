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

resource "ibm_tg_gateway" "transit_gateway" {
  name           = "k8s-tgw"
  location       = "jp-osa"
  global         = true
  resource_group = var.resource_group_id
}

resource "ibm_tg_connection" "tg_connection_vpc" {
  gateway      = ibm_tg_gateway.transit_gateway.id
  network_type = "vpc"
  name         = "k8s-conn-vpc"
  network_id   = var.vpc_crn
}

resource "ibm_tg_connection" "tg_connection_powervs" {
  gateway      = ibm_tg_gateway.transit_gateway.id
  network_type = "power_virtual_server"
  name         = "k8s-conn-powervs"
  network_id   = var.powervs_crn
}
