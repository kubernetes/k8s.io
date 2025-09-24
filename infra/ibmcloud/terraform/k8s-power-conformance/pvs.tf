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

resource "ibm_pi_key" "sshkey" {
  pi_key_name          = "k8s-prow-sshkey"
  pi_ssh_key           = module.secrets_manager.k8s_prow_ssh_public_key
  pi_cloud_instance_id = var.service_instance_id
}

module "powervs_workspace_sao01" {
  providers = {
    ibm = ibm.powervs_sao01
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "sao01"
  pi_workspace_name = "k8s-boskos-powervs-sao01"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_lon04" {
  providers = {
    ibm = ibm.powervs_lon04
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "lon04"
  pi_workspace_name = "k8s-boskos-powervs-lon04"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_lon06" {
  providers = {
    ibm = ibm.powervs_lon06
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "lon06"
  pi_workspace_name = "k8s-boskos-powervs-lon06"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_syd04" {
  providers = {
    ibm = ibm.powervs_syd04
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "syd04"
  pi_workspace_name = "k8s-boskos-powervs-syd04"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_syd05" {
  providers = {
    ibm = ibm.powervs_syd05
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "syd05"
  pi_workspace_name = "k8s-boskos-powervs-syd05"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_syd05_1" {
  providers = {
    ibm = ibm.powervs_syd05
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "syd05"
  pi_workspace_name = "k8s-boskos-powervs-syd05-01"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_tok04" {
  providers = {
    ibm = ibm.powervs_tok04
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "tok04"
  pi_workspace_name = "k8s-boskos-powervs-tok04"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_lon04_1" {
  providers = {
    ibm = ibm.powervs_lon04
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "lon04"
  pi_workspace_name = "k8s-boskos-powervs-lon04-01"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_lon04_2" {
  providers = {
    ibm = ibm.powervs_lon04
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "lon04"
  pi_workspace_name = "k8s-boskos-powervs-lon04-02"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}
