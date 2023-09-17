/*
Copyright 2021 The Kubernetes Authors.

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
  workload_identity_service_accounts = {
    prow-build = {
      description = "default service account for pods in ${local.cluster_name}"
      additional_workload_identity_principals = [
        "serviceAccount:${module.project.project_id}.svc.id.goog[test-pods/k8s-kops-test]"
      ]
    }
    boskos-janitor = {
      description = "used by boskos-janitor in ${local.cluster_name}"
    }
    kubernetes-external-secrets = {
      description       = "sync K8s secrets from GSM in this and other projects"
      project_roles     = ["roles/secretmanager.secretAccessor"],
      cluster_namespace = "kubernetes-external-secrets"
      additional_workload_identity_principals = [
        "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.eks_cluster.name}/*"
      ]
    }
  }
}

module "workload_identity_service_accounts" {
  for_each                                = local.workload_identity_service_accounts
  source                                  = "../modules/workload-identity-service-account"
  project_id                              = module.project.project_id
  name                                    = each.key
  description                             = each.value.description
  cluster_namespace                       = lookup(each.value, "cluster_namespace", local.pod_namespace)
  project_roles                           = lookup(each.value, "project_roles", [])
  additional_workload_identity_principals = lookup(each.value, "additional_workload_identity_principals", [])
}
