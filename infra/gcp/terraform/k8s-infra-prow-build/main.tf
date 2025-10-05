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

module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name            = "k8s-infra-prow-build"
  project_id      = "k8s-infra-prow-build"
  folder_id       = "411137699919"
  billing_account = "018801-93540E-22A20E"

  # Sane project defaults
  default_service_account     = "keep"
  disable_services_on_destroy = false
  create_project_sa           = false
  random_project_id           = false
  auto_create_network         = true
  activate_apis = [
    "secretmanager.googleapis.com",
    "cloudasset.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudkms.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "bigquery.googleapis.com"
  ]
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

module "prod_intel_pool" {
  source         = "terraform-google-modules/kubernetes-engine/google//modules/gke-node-pool"
  version        = "~> 40.0"
  project_id     = module.project.project_id
  name           = "pool8-intel"
  cluster        = module.prow_build_cluster.cluster.name
  node_locations = ["us-central1-b", "us-central1-c", "us-central1-f"]

  autoscaling = {
    max_node_count = 100
    min_node_count = 1
  }

  node_config = {
    service_account = module.prow_build_cluster.cluster_node_sa.email
    machine_type    = "c4-highmem-8-lssd"
    disk_type       = "hyperdisk-balanced"
    image_type      = "COS_CONTAINERD"
    kubelet_config = {
      single_process_oom_kill = false # https://github.com/kubernetes-sigs/prow/issues/210
    }
    shielded_instance_config = {
      enable_secure_boot = true
    }
  }
}

module "prod_amd_pool" {
  source         = "terraform-google-modules/kubernetes-engine/google//modules/gke-node-pool"
  version        = "~> 40.0"
  project_id     = module.project.project_id
  name           = "pool8-amd"
  cluster        = module.prow_build_cluster.cluster.name
  node_locations = ["us-central1-b", "us-central1-c", "us-central1-f"]

  autoscaling = {
    max_node_count = 100
    min_node_count = 1
  }

  node_config = {
    service_account = module.prow_build_cluster.cluster_node_sa.email
    machine_type    = "c4d-highmem-8-lssd"
    disk_type       = "hyperdisk-balanced"
    image_type      = "COS_CONTAINERD"
    kubelet_config = {
      single_process_oom_kill = false # https://github.com/kubernetes-sigs/prow/issues/210
    }
    shielded_instance_config = {
      enable_secure_boot = true
    }
  }
}

module "prod_arm_pool" {
  source         = "terraform-google-modules/kubernetes-engine/google//modules/gke-node-pool"
  version        = "~> 40.0"
  project_id     = module.project.project_id
  name           = "pool8-arm"
  cluster        = module.prow_build_cluster.cluster.name
  node_locations = ["us-central1-b", "us-central1-c", "us-central1-f"]

  autoscaling = {
    max_node_count = 100
    min_node_count = 1
  }

  node_config = {
    service_account = module.prow_build_cluster.cluster_node_sa.email
    machine_type    = "c4a-highmem-8-lssd"
    disk_type       = "hyperdisk-balanced"
    image_type      = "COS_CONTAINERD"
    kubelet_config = {
      single_process_oom_kill = false # https://github.com/kubernetes-sigs/prow/issues/210
    }
    shielded_instance_config = {
      enable_secure_boot = true
    }
  }
}
