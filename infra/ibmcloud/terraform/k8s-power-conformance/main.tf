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

module "iam_custom_role" {
  source = "./modules/iam/custom_role"
}

module "service_ids" {
  depends_on                = [module.iam_custom_role]
  source                    = "./modules/iam/service_ids"
  project_resource_group_id = module.resource_group.k8s_project_rg_id
}

module "iam_access_groups" {
  depends_on                = [module.iam_custom_role]
  source                    = "./modules/iam/access_groups"
  resource_group_id         = module.resource_group.k8s_rg_id
  project_resource_group_id = module.resource_group.k8s_project_rg_id
}

module "secrets_manager" {
  source                         = "./modules/secrets_manager"
  secrets_manager_id             = var.secrets_manager_id
  pvs_access_group_id            = module.iam_access_groups.pvs_access_group_id
  janitor_access_group_id        = module.iam_access_groups.janitor_access_group_id
  secret_rotator_access_group_id = module.iam_access_groups.secret_rotator_access_group_id
  apikey                         = module.service_ids.sm_read_apikey
}
