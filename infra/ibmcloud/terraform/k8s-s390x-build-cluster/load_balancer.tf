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
resource "ibm_is_lb" "k8s_load_balancer" {
  name            = "k8s-s390x-lb"
  type            = "public"
  subnets         = [data.ibm_is_subnet.subnet.id]
  resource_group  = data.ibm_resource_group.resource_group.id
  security_groups = [data.ibm_is_security_group.master_sg.id]
}

resource "ibm_is_lb_pool" "k8s_api_pool" {
  name                = "k8s-api-server-pool"
  lb                  = ibm_is_lb.k8s_load_balancer.id
  protocol            = "tcp"
  algorithm           = "round_robin"
  health_delay        = 5
  health_retries      = 2
  health_timeout      = 2
  health_type         = "tcp"
  health_monitor_url  = "/"
  health_monitor_port = 6443
}

resource "ibm_is_lb_listener" "k8s_api_listener" {
  lb           = ibm_is_lb.k8s_load_balancer.id
  protocol     = "tcp"
  port         = 6443
  default_pool = ibm_is_lb_pool.k8s_api_pool.pool_id
}

resource "ibm_is_lb_pool_member" "k8s_api_members" {
  count          = var.control_plane.count
  lb             = ibm_is_lb.k8s_load_balancer.id
  pool           = ibm_is_lb_pool.k8s_api_pool.pool_id
  port           = 6443
  target_address = ibm_is_instance.control_plane[count.index].primary_network_interface[0].primary_ipv4_address
}
