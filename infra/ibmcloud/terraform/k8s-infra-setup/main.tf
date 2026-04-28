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

module "resource_group" {
  source = "./modules/resource_group"
}

module "secrets_manager" {
  source            = "./modules/secrets_manager"
  resource_group_id = module.resource_group.k8s_rg_id
}

module "vpc" {
  providers = {
    ibm = ibm.vpc
  }
  source            = "./modules/vpc"
  resource_group_id = module.resource_group.k8s_rg_id
}

module "transit_gateway" {
  depends_on = [module.vpc]
  providers = {
    ibm = ibm.vpc
  }
  source            = "./modules/transit_gateway"
  resource_group_id = module.resource_group.k8s_rg_id
  vpc_crn           = module.vpc.crn
  powervs_crn       = ibm_pi_workspace.build_cluster.crn
}
