/*
Copyright 2023 The Kubernetes Authors.

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

assume_role = true
is_canary_installation = true

cluster_name    = "prow-build-canary-cluster"
cluster_region  = "us-east-2"
cluster_version = "1.25"

vpc_cidr                  = "10.3.0.0/16"
vpc_secondary_cidr_blocks = ["10.4.0.0/16", "10.5.0.0/16"]
vpc_public_subnet         = ["10.3.0.0/18", "10.3.64.0/18", "10.3.128.0/18"]
vpc_private_subnet        = ["10.4.0.0/18", "10.4.64.0/18", "10.4.128.0/18"]
vpc_intra_subnet          = ["10.5.0.0/18", "10.5.64.0/18", "10.5.128.0/18"]

# Ubuntu EKS optimized AMI: https://cloud-images.ubuntu.com/aws-eks/
node_ami            = "ami-03de35fda144b3672"
node_instance_types = ["r5d.xlarge"]
node_volume_size    = 100

node_min_size                   = 1
node_max_size                   = 10
node_desired_size               = 1
node_max_unavailable_percentage = 100 # To ease testing

cluster_autoscaler_version = "v1.25.0"
