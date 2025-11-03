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

locals {
  api_servers       = var.control_plane_ips
  api_servers_count = var.control_plane_count
}

data "ibm_is_vpc" "vpc" {
  name = var.vpc_name
}

data "ibm_resource_group" "group" {
  name = var.resource_group_name
}

resource "ibm_is_lb" "load_balancer_external" {
  lifecycle {
    ignore_changes = [
      resource_group
    ]
  }
  name           = "k8s-control-plane-api-lb"
  resource_group = data.ibm_resource_group.group.id
  subnets        = data.ibm_is_vpc.vpc.subnets.*.id
  type           = "public"
}

# api listener and backend pool (external)
resource "ibm_is_lb_listener" "api_listener_external" {
  lb           = ibm_is_lb.load_balancer_external.id
  port         = 6443
  protocol     = "tcp"
  default_pool = ibm_is_lb_pool.api_pool_external.id
}

resource "ibm_is_lb_pool" "api_pool_external" {
  depends_on = [ibm_is_lb.load_balancer_external]

  name           = "api-server"
  lb             = ibm_is_lb.load_balancer_external.id
  algorithm      = "round_robin"
  protocol       = "tcp"
  health_delay   = 60
  health_retries = 5
  health_timeout = 30
  health_type    = "tcp"
}

resource "ibm_is_lb_pool_member" "api_member_external" {
  depends_on = [ibm_is_lb_listener.api_listener_external]
  count      = local.api_servers_count

  lb             = ibm_is_lb.load_balancer_external.id
  pool           = ibm_is_lb_pool.api_pool_external.id
  port           = 6443
  target_address = local.api_servers[count.index]
}
