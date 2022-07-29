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

// Some of the roles for these service accounts are assigned in bash or other
// terraform modules, so as to keep the permissions necessary to run this
// terraform module scoped to "roles/owner" for module.project.project_id

locals {
  workload_identity_service_accounts = {
    prow-build-trusted = {
      description = "default service account for pods in ${local.cluster_name}"
    }
    // also assigned roles by:
    // - bash/ensure-staging-storage.sh
    gcb-builder = {
      name        = "gcb-builder"
      description = "trigger GCB builds in all k8s-staging projects"
    }
    // also assigned roles by:
    // - terraform/k8s-infra-prow-build
    // - bash/ensure-main-project.sh
    prow-deployer = {
      description   = "deploys k8s resources to k8s clusters"
      project_roles = ["roles/container.admin"]
    }
    // also assigned roles by:
    // - terraform/kubernetes-public
    k8s-cve-feed = {
      description = "write to gs://k8s-cve-feed"
    }
    k8s-keps = {
      description   = "write to gs://k8s-keps"
    }
    k8s-metrics = {
      description   = "read bigquery and write to gs://k8s-metrics"
      project_roles = ["roles/bigquery.user"]
    }
    k8s-triage = {
      description   = "read bigquery and write to gs://k8s-triage"
      project_roles = ["roles/bigquery.user"]
    }
    kubernetes-external-secrets = {
      description       = "sync K8s secrets from GSM in this and other projects"
      project_roles     = ["roles/secretmanager.secretAccessor"]
      cluster_namespace = "kubernetes-external-secrets"
    }
  }
}

module "workload_identity_service_accounts" {
  for_each          = local.workload_identity_service_accounts
  source            = "../modules/workload-identity-service-account"
  project_id        = module.project.project_id
  name              = each.key
  description       = each.value.description
  cluster_namespace = lookup(each.value, "cluster_namespace", local.pod_namespace)
  project_roles     = lookup(each.value, "project_roles", [])
}
