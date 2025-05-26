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
- Shared local values for use by other files in this module
- GCP Project k8s-infra-prow-build to hold a prow build cluster
- Project-level IAM bindings
- GKE cluster configuration for the build cluster
- GKE nodepool configuration for the build cluster
*/

locals {
  project_id        = "k8s-infra-prow-build"
  cluster_name      = "prow-build"  // The name of the cluster defined in this file
  cluster_location  = "us-central1" // The GCP location (region or zone) where the cluster should be created
  bigquery_location = "US"          // The bigquery specific location where the dataset should be created
  pod_namespace     = "test-pods"   // MUST match whatever prow is configured to use when it schedules to this cluster
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
  project = module.project.project_id
  role    = "roles/owner"
  member  = "group:k8s-infra-prow-oncall@kubernetes.io"
}

// Role created by ensure-organization.sh, use a data source to ensure it exists
data "google_iam_role" "prow_viewer" {
  name = "${data.google_organization.org.name}/roles/prow.viewer"
}

// Ensure k8s-infra-prow-viewers@kuberentes.io has prow.viewer access to this project
resource "google_project_iam_member" "k8s_infra_prow_viewers" {
  project = module.project.project_id
  role    = data.google_iam_role.prow_viewer.name
  member  = "group:k8s-infra-prow-viewers@kubernetes.io"
}

// Allow prow-deployer service account in k8s-infra-prow-build-trusted to deploy
// to the cluster defined in here
resource "google_project_iam_member" "prow_deployer_for_prow_build" {
  project = module.project.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:prow-deployer@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"
}

module "prow_build_cluster" {
  source             = "../modules/gke-cluster"
  project_name       = module.project.project_id
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
  source       = "../modules/gke-nodepool"
  project_name = module.project.project_id
  cluster_name = module.prow_build_cluster.cluster.name
  location     = module.prow_build_cluster.cluster.location
  node_locations = [
    "us-central1-b",
    "us-central1-c",
    "us-central1-f",
  ]
  name                      = "pool5"
  initial_count             = 1
  min_count                 = 0
  max_count                 = 0
  image_type                = "UBUNTU_CONTAINERD"
  machine_type              = "n1-highmem-8"
  disk_size_gb              = 100
  disk_type                 = "pd-standard"
  ephemeral_local_ssd_count = 2 # each is 375GB
  service_account           = module.prow_build_cluster.cluster_node_sa.email
}

module "prow_build_nodepool_c4_highmem_8_localssd" {
  source       = "../modules/gke-nodepool"
  project_name = module.project.project_id
  cluster_name = module.prow_build_cluster.cluster.name
  location     = module.prow_build_cluster.cluster.location
  node_locations = [
    "us-central1-b",
    "us-central1-c",
    "us-central1-f",
  ]
  name            = "pool6"
  initial_count   = 1
  min_count       = 1
  max_count       = 80
  machine_type    = "c4-highmem-8"
  disk_size_gb    = 500
  disk_type       = "hyperdisk-balanced"
  service_account = module.prow_build_cluster.cluster_node_sa.email
}


module "sig_node_node_pool_1_n4_highmem_8" {

  source       = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gke-nodepool?ref=v39.0.0&depth=1"
  project_id   = module.project.project_id
  name         = "sig-node-pool1"
  location     = module.prow_build_cluster.cluster.location
  cluster_name = module.prow_build_cluster.cluster.name

  service_account = {
    email        = module.prow_build_cluster.cluster_node_sa.email
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  nodepool_config = {
    autoscaling = {
      max_node_count = 10
      min_node_count = 1 # 1 per zone
    }
    management = {
      auto_repair  = true
      auto_upgrade = true
    }
  }

  node_config = {
    machine_type                  = "n4-highmem-8"
    disk_type                     = "hyperdisk-balanced"
    image_type                    = "COS_CONTAINERD"
    gvnic                         = true
    workload_metadata_config_mode = "GKE_METADATA"
    shielded_instance_config = {
      enable_secure_boot = true
    }
  }


  taints = { dedicated = { value = "sig-node", effect = "NO_SCHEDULE" } }
}

module "prow_build_nodepool_t2a_standard_8" {
  source       = "../modules/gke-nodepool"
  project_name = module.project.project_id
  cluster_name = module.prow_build_cluster.cluster.name
  location     = module.prow_build_cluster.cluster.location
  node_locations = [
    "us-central1-a",
    "us-central1-b",
  ]
  name          = "pool6-arm64"
  initial_count = 1
  min_count     = 1
  max_count     = 10
  image_type    = "UBUNTU_CONTAINERD"
  machine_type  = "t2a-standard-8"
  disk_size_gb  = 500
  disk_type     = "pd-ssd"
  // GKE automatically taints arm64 nodes
  // https://cloud.google.com/kubernetes-engine/docs/how-to/prepare-arm-workloads-for-deployment#overview
  # ephemeral_local_ssd_count = 2 # each is 375GB
  service_account = module.prow_build_cluster.cluster_node_sa.email
}
