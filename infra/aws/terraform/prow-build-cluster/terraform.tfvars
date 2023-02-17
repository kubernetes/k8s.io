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

vpc_cidr = "10.0.0.0/16"

cluster_name    = "prow-build-cluster"
cluster_region  = "us-east-2"
cluster_version = "1.23"

# Ubuntu EKS optimized AMI: https://cloud-images.ubuntu.com/aws-eks/
node_ami = "ami-0a8fed39d4c2b85c1"
#node_instance_types = ["r5ad.4xlarge"] # Revert to this instance size after bumping up limits.
node_instance_types = ["r5ad.2xlarge"]
node_volume_size    = 100
# TODO: Update this after support ticket gets approved.
node_min_size     = 2
node_max_size     = 4
node_desired_size = 3
