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

module "powervs_workspace_eu_de_1_01" {
  providers = {
    ibm = ibm.powervs_eu_de_1
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "eu-de-1"
  pi_workspace_name = "k8s-boskos-powervs-eu-de-1-01"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_eu_de_1_02" {
  providers = {
    ibm = ibm.powervs_eu_de_1
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "eu-de-1"
  pi_workspace_name = "k8s-boskos-powervs-eu-de-1-02"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_eu_de_1_03" {
  providers = {
    ibm = ibm.powervs_eu_de_1
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "eu-de-1"
  pi_workspace_name = "k8s-boskos-powervs-eu-de-1-03"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_eu_de_2_01" {
  providers = {
    ibm = ibm.powervs_eu_de_2
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "eu-de-2"
  pi_workspace_name = "k8s-boskos-powervs-eu-de-2-01"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_eu_de_2_02" {
  providers = {
    ibm = ibm.powervs_eu_de_2
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "eu-de-2"
  pi_workspace_name = "k8s-boskos-powervs-eu-de-2-02"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_eu_de_2_03" {
  providers = {
    ibm = ibm.powervs_eu_de_2
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "eu-de-2"
  pi_workspace_name = "k8s-boskos-powervs-eu-de-2-03"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_tor_01_1" {
  providers = {
    ibm = ibm.powervs_tor01
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "tor01"
  pi_workspace_name = "k8s-boskos-powervs-tor01-01"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_tor_01_2" {
  providers = {
    ibm = ibm.powervs_tor01
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "tor01"
  pi_workspace_name = "k8s-boskos-powervs-tor01-02"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}

module "powervs_workspace_tor_01_3" {
  providers = {
    ibm = ibm.powervs_tor01
  }
  source            = "./modules/pvs_workspace"
  datacenter        = "tor01"
  pi_workspace_name = "k8s-boskos-powervs-tor01-03"
  resource_group_id = module.resource_group.k8s_rg_id
  image_name        = var.image_name
}
