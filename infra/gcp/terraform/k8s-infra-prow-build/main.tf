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

module "prow_build_nodepool_c4_highmem_8_localssd" {
  source       = "../modules/gke-nodepool"
  project_name = module.project.project_id
  cluster_name = module.prow_build_cluster.cluster.name
  location     = module.prow_build_cluster.cluster.location
  node_locations = [
    "us-central1-a",
    "us-central1-b",
    "us-central1-c",
    "us-central1-f",
  ]
  name                         = "pool6"
  initial_count                = 1
  min_count                    = 1
  max_count                    = 250 # total across all zones
  machine_type                 = "c4-highmem-8-lssd"
  disk_size_gb                 = 100
  disk_type                    = "hyperdisk-balanced"
  enable_nested_virtualization = true
  service_account              = module.prow_build_cluster.cluster_node_sa.email
  // This taint exists to bias workloads on to the C4D nodepool first, if we can't secure a C4D node
  // then we schedule on to a C4 node. C4D performs better than C4 but it is capacity constrained at times.
  // Also, nested virt doesn't work on C4D or C4A
  taints = [
    {
      key    = "spare"
      value  = "true"
      effect = "PREFER_NO_SCHEDULE"
    }
  ]
}

module "prow_build_nodepool_c4d_highmem_8_localssd" {
  source       = "../modules/gke-nodepool"
  project_name = module.project.project_id
  cluster_name = module.prow_build_cluster.cluster.name
  location     = module.prow_build_cluster.cluster.location
  node_locations = [
    "us-central1-a",
    "us-central1-b",
    "us-central1-c",
  ]
  name            = "pool7"
  initial_count   = 1
  min_count       = 10
  max_count       = 250                  # total across all zones
  machine_type    = "c4d-highmem-8-lssd" # has 1 local ssd disks attached
  disk_size_gb    = 100
  disk_type       = "hyperdisk-balanced"
  service_account = module.prow_build_cluster.cluster_node_sa.email
}

module "prow_build_nodepool_c4a_highmem_8_localssd" {
  source       = "../modules/gke-nodepool"
  project_name = module.project.project_id
  cluster_name = module.prow_build_cluster.cluster.name
  location     = module.prow_build_cluster.cluster.location
  node_locations = [
    "us-central1-a",
    "us-central1-b",
    "us-central1-c",
    "us-central1-f",
  ]
  name          = "pool7-arm64"
  initial_count = 1
  min_count     = 3
  max_count     = 100                  # total across all zones
  machine_type  = "c4a-highmem-8-lssd" # has 2 local ssd disks attached
  disk_size_gb  = 100
  disk_type     = "hyperdisk-balanced"
  // GKE automatically taints arm64 nodes
  // https://cloud.google.com/kubernetes-engine/docs/how-to/prepare-arm-workloads-for-deployment#overview
  service_account = module.prow_build_cluster.cluster_node_sa.email
}
