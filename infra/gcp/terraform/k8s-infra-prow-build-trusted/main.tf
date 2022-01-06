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
- Google Project k8s-infra-prow-build-trusted to hold a prow build cluster
- Project-level IAM bindings
- GKE cluster configuration for the build cluster
- GKE nodepool configuration for the build cluster
*/

locals {
  project_id        = "k8s-infra-prow-build-trusted"
  cluster_name      = "prow-build-trusted" // The name of the cluster defined in this file
  cluster_location  = "us-central1"        // The GCP location (region or zone) where the cluster should be created
  bigquery_location = "US"                 // The bigquery specific location where the dataset should be created
  pod_namespace     = "test-pods"          // MUST match whatever prow is configured to use when it schedules to this cluster
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

// The image/machine/disk match prow-build for consistency's sake
module "prow_build_nodepool" {
  source          = "../modules/gke-nodepool"
  project_name    = module.project.project_id
  cluster_name    = module.prow_build_cluster.cluster.name
  location        = module.prow_build_cluster.cluster.location
  name            = "trusted-pool1"
  initial_count   = 1
  min_count       = 1
  max_count       = 6
  image_type      = "UBUNTU_CONTAINERD"
  machine_type    = "n1-highmem-8"
  disk_size_gb    = 200
  disk_type       = "pd-ssd"
  service_account = module.prow_build_cluster.cluster_node_sa.email
}

