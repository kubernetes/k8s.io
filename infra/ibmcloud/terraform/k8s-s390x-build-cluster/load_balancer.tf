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
resource "ibm_is_lb" "public" {
  name            = "k8s-s390x-ci"
  type            = "public"
  subnets         = [data.ibm_is_subnet.subnet.id]
  resource_group  = data.ibm_resource_group.resource_group.id
  security_groups = [data.ibm_is_security_group.control_plane_sg.id]
}

resource "ibm_is_lb_pool" "k8s_api_pool" {
  name                = "k8s-api-server-pool"
  lb                  = ibm_is_lb.public.id
  protocol            = "tcp"
  algorithm           = "round_robin"
  health_delay        = 5
  health_retries      = 2
  health_timeout      = 2
  health_type         = "tcp"
  health_monitor_url  = "/"
  health_monitor_port = var.api_server_port
}

resource "ibm_is_lb_listener" "k8s_api_listener" {
  lb           = ibm_is_lb.public.id
  protocol     = "tcp"
  port         = var.api_server_port
  default_pool = ibm_is_lb_pool.k8s_api_pool.pool_id
}

resource "ibm_is_lb_pool_member" "k8s_api_members" {
  for_each = ibm_is_instance.control_plane

  lb             = ibm_is_lb.public.id
  pool           = ibm_is_lb_pool.k8s_api_pool.pool_id
  port           = var.api_server_port
  target_address = each.value.primary_network_interface[0].primary_ipv4_address
}
