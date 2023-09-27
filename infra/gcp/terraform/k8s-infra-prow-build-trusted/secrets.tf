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
  build_cluster_secrets = {
    capdo-quayio-registry-secret = {
      group  = "sig-cluster-lifecycle"
      owners = "k8s-infra-staging-cluster-api-do@kubernetes.io"
    }
    cncf-ci-github-token = {
      group  = "sig-testing"
      owners = "k8s-infra-ii-coop@kubernetes.io"
    }
    eks-prow-build-cluster-kubeconfig = {
      group  = "sig-k8s-infra"
      owners = "k8s-infra-aws-admins@kubernetes.io"
    }
    k8s-cip-test-prod-service-account = {
      group  = "sig-release"
      owners = "k8s-infra-release-admins@kubernetes.io"
    }
    k8s-gcr-audit-test-prod-service-account = {
      group  = "sig-release"
      owners = "k8s-infra-release-admins@kubernetes.io"
    }
    k8s-infra-kops-prow-build-kubeconfig = {
      group = "sig-cluster-lifecycle"
      owners = "k8s-infra-kops-maintainers@kubernetes.io"
    }
    k8s-release-enhancements-triage-github-token = {
      group  = "sig-release"
      owners = "k8s-infra-release-editors@kubernetes.io"
    }
    k8s-release-bug-triage-github-token = {
      group  = "sig-release"
      owners = "k8s-infra-release-editors@kubernetes.io"
    }
    k8s-triage-robot-github-token = {
      group  = "sig-contributor-experience"
      owners = "github@kubernetes.io"
    }
    registry-k8s-io-s3-writer = {
      group  = "sig-release"
      owners = "k8s-infra-release-admins@kubernetes.io"
    }
    service-account = {
      group  = "sig-testing"
      owners = "k8s-infra-prow-oncall@kubernetes.io"
    }
    slack-tempelis-auth = {
      group  = "sig-contributor-experience"
      owners = "k8s-infra-rbac-slack-infra@kubernetes.io"
    }
    snyk-token = {
      group  = "sig-architecture"
      owners = "k8s-infra-code-organization@kubernetes.io"
    }
  }
}

resource "google_secret_manager_secret" "build_cluster_secrets" {
  for_each  = local.build_cluster_secrets
  project   = module.project.project_id
  secret_id = each.key
  labels = {
    group = each.value.group
  }
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_iam_binding" "build_cluster_secret_admins" {
  for_each  = local.build_cluster_secrets
  project   = google_secret_manager_secret.build_cluster_secrets[each.key].project
  secret_id = google_secret_manager_secret.build_cluster_secrets[each.key].id
  role      = "roles/secretmanager.admin"
  members = [
    "group:k8s-infra-prow-oncall@kubernetes.io",
    "group:${each.value.owners}"
  ]
}

data "google_secret_manager_secret" "capdo_quayio_registry_secret" {
  project   = module.project.project_id
  secret_id = "capdo-quayio-registry-secret"
}

resource "google_secret_manager_secret_iam_member" "k8s_prow_kes_sa_role_viewer" {
  project   = module.project.project_id
  secret_id = data.google_secret_manager_secret.capdo_quayio_registry_secret.id
  role      = "roles/secretmanager.viewer"
  member    = "serviceAccount:kubernetes-external-secrets-sa@k8s-prow.iam.gserviceaccount.com"
}

resource "google_secret_manager_secret_iam_member" "k8s_prow_kes_sa_role_accessor" {
  project   = module.project.project_id
  secret_id = data.google_secret_manager_secret.capdo_quayio_registry_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:kubernetes-external-secrets-sa@k8s-prow.iam.gserviceaccount.com"
}
