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

module "load_balancer" {

  providers = {
    ibm = ibm.vpc
  }

  depends_on          = [ibm_pi_instance.control_plane]
  source              = "./modules/load_balancer"
  control_plane_count = var.control_plane["count"]
  control_plane_ips   = data.ibm_pi_instance_ip.control_plane_ip.*.ip
  vpc_name            = var.vpc_name
  resource_group_name = var.resource_group_name
}
