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

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.3"

  project_id      = module.project.project_id
  network_name    = "prow"
  routing_mode    = "GLOBAL"
  enable_ipv6_ula = true

  subnets = [
    {
      subnet_name           = "subnet-01"
      subnet_ip             = "10.250.0.0/20"
      subnet_region         = "us-central1"
      subnet_private_access = "true"
      ipv6_access_type      = "EXTERNAL"
      stack_type            = "IPV4_IPV6"
    },
  ]

  secondary_ranges = {
    subnet-01 = [
      {
        range_name    = "prow-services"
        ip_cidr_range = "10.250.128.0/20"
      },
      {
        range_name    = "prow-pods"
        ip_cidr_range = "10.250.160.0/20"
      },
      {
        range_name    = "utility-services"
        ip_cidr_range = "10.250.192.0/20"
      },
      {
        range_name    = "utility-pods"
        ip_cidr_range = "10.250.224.0/20"
      }
    ]
  }
}

module "nat" {
  source        = "terraform-google-modules/cloud-nat/google"
  version       = "~> 5.0"
  project_id    = module.project.project_id
  nat_ips       = google_compute_address.prow_nat.*.self_link
  region        = "us-central1"
  network       = module.vpc.network_name
  create_router = true
  router        = "prow-nat"
  name          = "prow-nat"
}
