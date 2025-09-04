/*
Copyright 2024 The Kubernetes Authors.

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

// WARNING, MAKE SURE YOU DON"T DESTROY THESE CLUSTERS ACCIDENTALLY
module "prow" {
  source                       = "terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster"
  version                      = "~> 37.1"
  project_id                   = module.project.project_id
  name                         = "prow"
  region                       = "us-central1"
  zones                        = ["us-central1-a", "us-central1-b"]
  release_channel              = "REGULAR"
  network                      = module.vpc.network_name
  subnetwork                   = module.vpc.subnets["us-central1/subnet-01"].name
  ip_range_pods                = "prow-pods"
  ip_range_services            = "prow-services"
  stack_type                   = "IPV4_IPV6"
  http_load_balancing          = true
  datapath_provider            = "ADVANCED_DATAPATH"
  filestore_csi_driver         = false
  create_service_account       = false
  remove_default_node_pool     = true
  enable_l4_ilb_subsetting     = true
  enable_private_nodes         = true
  enable_cost_allocation       = true
  gateway_api_channel          = "CHANNEL_STANDARD"
  master_ipv4_cidr_block       = "10.254.0.16/28"
  authenticator_security_group = "gke-security-groups@kubernetes.io"
  cluster_resource_labels = {
    cluster     = "prow"
    role        = "prow"
    environment = "production"
  }

  node_pools = [
    {
      name               = "prod-v1"
      machine_type       = "c4-standard-16"
      node_locations     = "us-central1-a,us-central1-b,us-central1-c"
      min_count          = 2
      max_count          = 3
      disk_size_gb       = 100
      disk_type          = "hyperdisk-balanced"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      service_account    = google_service_account.gke_nodes.email
      enable_secure_boot = true
      initial_node_count = 1
      location_policy    = "BALANCED"
    },
  ]

  node_pools_labels = {
    all = {
      environment = "production"
    }
  }
}

module "utility_cluster" {
  source                       = "terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster"
  version                      = "~> 37.1"
  project_id                   = module.project.project_id
  name                         = "utility"
  region                       = "us-central1"
  zones                        = ["us-central1-a", "us-central1-b"]
  release_channel              = "REGULAR"
  network                      = module.vpc.network_name
  subnetwork                   = module.vpc.subnets["us-central1/subnet-01"].name
  ip_range_pods                = "utility-pods"
  ip_range_services            = "utility-services"
  stack_type                   = "IPV4_IPV6"
  http_load_balancing          = true
  datapath_provider            = "ADVANCED_DATAPATH"
  filestore_csi_driver         = false
  create_service_account       = false
  remove_default_node_pool     = true
  enable_l4_ilb_subsetting     = true
  enable_private_nodes         = true
  enable_cost_allocation       = true
  master_ipv4_cidr_block       = "10.254.0.0/28"
  authenticator_security_group = "gke-security-groups@kubernetes.io"

  cluster_resource_labels = {
    cluster     = "utility"
    role        = "utility"
    environment = "production"
  }

  master_authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "external-v4"
    },
  ]

  node_pools = [
    {
      name               = "prod-v1"
      machine_type       = "c3-standard-4"
      node_locations     = "us-central1-a,us-central1-b"
      min_count          = 1
      max_count          = 3
      disk_size_gb       = 100
      disk_type          = "pd-ssd"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      service_account    = google_service_account.gke_nodes.email
      enable_secure_boot = true
      initial_node_count = 1
      location_policy    = "BALANCED"
    },
  ]

  node_pools_labels = {
    all = {
      environment = "production"
      type        = "system"
    }
  }
}
