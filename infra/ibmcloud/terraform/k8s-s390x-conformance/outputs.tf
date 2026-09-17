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

output "boskos_janitor_api_key_id" {
  value = module.secrets_manager.k8s_janitor_secret_id
}

output "secret_rotator_api_key_id" {
  value = module.secrets_manager.k8s_secret_rotator_id
}

output "boskos_resource_names" {
  value = sort(keys(local.boskos_resources))
}

output "boskos_resource_userdata" {
  value = {
    for name, resource in local.boskos_resources : name => {
      "region"         = var.region
      "resource-group" = local.vpc_resource_group_id
      "subnet-id"      = module.vpc[name].subnet_id
      "subnet-name"    = module.vpc[name].subnet_name
      "vpc-id"         = module.vpc[name].vpc_id
      "vpc-name"       = module.vpc[name].vpc_name
      "zone"           = resource.zone
    }
  }
}

output "boskos_resources_yaml" {
  value = yamlencode({
    resources = [
      {
        names = sort(keys(local.boskos_resources))
        state = "free"
        type  = "vpc-service"
      }
    ]
  })
}
