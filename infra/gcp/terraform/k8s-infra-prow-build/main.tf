/*
Copyright 2020 The Kubernetes Authors.

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

/*
This file defines:
- GCP Project k8s-infra-prow-build to hold a prow build cluster
- GCP Service Account for k8s-infra-prow-build pods (bound via workload identity to a KSA of the same name)
- GCP Service Account for boskos-janitor (bound via workload identity to a KSA of the same name)
- GKE cluster configuration for prow-build
- GKE nodepool configuration for prow-build
*/

locals {
  project_id        = "k8s-infra-prow-build"
  cluster_name      = "prow-build"  // The name of the cluster defined in this file
  cluster_location  = "us-central1" // The GCP location (region or zone) where the cluster should be created
  bigquery_location = "US"          // The bigquery specific location where the dataset should be created
  pod_namespace     = "test-pods"   // MUST match whatever prow is configured to use when it schedules to this cluster

  // Service Accounts in ${pod_namespace} (usable via Workload Identity)
  cluster_sa_name                     = "prow-build"                  // Name of the GSA and KSA that pods use by default
  boskos_janitor_sa_name              = "boskos-janitor"              // Name of the GSA and KSA used by boskos-janitor
  kubernetes_external_secrets_sa_name = "kubernetes-external-secrets" // Allowed to read from GSM in this and other projects

}

data "google_organization" "org" {
  domain = "kubernetes.io"
}

module "project" {
  source       = "../modules/gke-project"
  project_id   = local.project_id
  project_name = local.project_id
}

// Ensure k8s-infra-prow-oncall@kuberentes.io has owner access to this project
resource "google_project_iam_member" "k8s_infra_prow_oncall" {
  project = local.project_id
  role    = "roles/owner"
  member  = "group:k8s-infra-prow-oncall@kubernetes.io"
}

// Role created by ensure-organization.sh, use a data source to ensure it exists
data "google_iam_role" "prow_viewer" {
  name = "${data.google_organization.org.name}/roles/prow.viewer"
}

// Ensure k8s-infra-prow-viewers@kuberentes.io has prow.viewer access to this project
resource "google_project_iam_member" "k8s_infra_prow_viewers" {
  project = local.project_id
  role    = data.google_iam_role.prow_viewer.name
  member  = "group:k8s-infra-prow-viewers@kubernetes.io"
}

module "prow_build_cluster_sa" {
  source            = "../modules/workload-identity-service-account"
  project_id        = local.project_id
  name              = local.cluster_sa_name
  description       = "default service account for pods in ${local.cluster_name}"
  cluster_namespace = local.pod_namespace
}

module "boskos_janitor_sa" {
  source            = "../modules/workload-identity-service-account"
  project_id        = local.project_id
  name              = local.boskos_janitor_sa_name
  description       = "used by boskos-janitor in ${local.cluster_name}"
  cluster_namespace = local.pod_namespace
}

module "kubernetes_external_secrets_sa" {
  source            = "../modules/workload-identity-service-account"
  project_id        = local.project_id
  name              = local.kubernetes_external_secrets_sa_name
  description       = "sync K8s secrets from GSM in this and other projects"
  cluster_namespace = "kubernetes-external-secrets"
  project_roles     = ["roles/secretmanager.secretAccessor"]
}

// external ip formerly managed by infra/gcp/bash/prow/ensure-e2e-projects.sh
resource "google_compute_address" "boskos_metrics" {
  name         = "boskos-metrics"
  description  = "to allow monitoring.k8s.prow.io to scrape boskos metrics"
  project      = local.project_id
  region       = local.cluster_location
  address_type = "EXTERNAL"
}

// external ip formerly managed by infra/gcp/bash/prow/ensure-e2e-projects.sh
resource "google_compute_address" "greenhouse_metrics" {
  name         = "greenhouse-metrics"
  description  = "to allow monitoring.k8s.prow.io to scrape greenhouse metrics"
  project      = local.project_id
  region       = local.cluster_location
  address_type = "EXTERNAL"
}

resource "google_compute_address" "kubernetes_external_secrets_metrics" {
  name         = "kubernetes-external-secrets-metrics"
  description  = "to allow monitoring.k8s.prow.io to scrape kubernetes-external-secrets metrics"
  project      = local.project_id
  region       = local.cluster_location
  address_type = "EXTERNAL"
}

locals {
  build_cluster_secrets = {
    prow-build-service-account = {
      group  = "sig-testing"
      owners = "k8s-infra-prow-oncall@kubernetes.io"
    }
    prow-build-ssh-key-secret = {
      group  = "sig-testing"
      owners = "k8s-infra-prow-oncall@kubernetes.io"
    }
  }
}

resource "google_secret_manager_secret" "build_cluster_secrets" {
  for_each  = local.build_cluster_secrets
  project   = local.project_id
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
  project   = local.project_id
  secret_id = each.key
  role      = "roles/secretmanager.admin"
  members = [
    "group:k8s-infra-prow-oncall@kubernetes.io",
    "group:${each.value.owners}"
  ]
}

module "prow_build_cluster" {
  source             = "../modules/gke-cluster"
  project_name       = local.project_id
  cluster_name       = local.cluster_name
  cluster_location   = local.cluster_location
  bigquery_location  = local.bigquery_location
  is_prod_cluster    = "true"
  release_channel    = "REGULAR"
  dns_cache_enabled  = "true"
  cloud_shell_access = false
}

# Why use UBUNTU_CONTAINERD for image_type?
# - ipv6 jobs need an ipv6 stack; COS lacks one, so use UBUNTU
# - k8s-prow-builds/prow cluster uses _CONTAINERD variant, keep parity
module "prow_build_nodepool_n1_highmem_8_localssd" {
  source                    = "../modules/gke-nodepool"
  project_name              = local.project_id
  cluster_name              = module.prow_build_cluster.cluster.name
  location                  = module.prow_build_cluster.cluster.location
  name                      = "pool5"
  initial_count             = 1
  min_count                 = 1
  max_count                 = 80
  image_type                = "UBUNTU_CONTAINERD"
  machine_type              = "n1-highmem-8"
  disk_size_gb              = 100
  disk_type                 = "pd-standard"
  ephemeral_local_ssd_count = 2 # each is 375GB
  service_account           = module.prow_build_cluster.cluster_node_sa.email
}

# Why the large machine type?
# - To maximize IOPs, which are CPU-limited for network attached storage
#
# NOTE: updating taints requires recreating the underlying resource, see module docs
module "greenhouse_nodepool" {
  source          = "../modules/gke-nodepool"
  project_name    = local.project_id
  cluster_name    = module.prow_build_cluster.cluster.name
  location        = module.prow_build_cluster.cluster.location
  name            = "greenhouse"
  labels          = { dedicated = "greenhouse" }
  taints          = [{ key = "dedicated", value = "greenhouse", effect = "NO_SCHEDULE" }]
  initial_count   = 1
  min_count       = 1
  max_count       = 1
  image_type      = "UBUNTU_CONTAINERD"
  machine_type    = "n1-standard-32"
  disk_size_gb    = 100
  disk_type       = "pd-standard"
  service_account = module.prow_build_cluster.cluster_node_sa.email
}
