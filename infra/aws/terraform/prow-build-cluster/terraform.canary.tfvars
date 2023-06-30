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

aws_account_id = "054318140392"

eks_cluster_viewers = [
  "pkprzekwas",
  "wozniakjan",
  "xmudrii"
]

eks_cluster_admins = [
  "pkprzekwas",
  "wozniakjan",
  "xmudrii"
]

cluster_name               = "prow-canary-cluster"
cluster_version            = "1.26"
cluster_autoscaler_version = "v1.26.2"

# Ubuntu EKS optimized AMI: https://cloud-images.ubuntu.com/aws-eks/
node_ami            = "ami-0e5789a9184c7d081"
node_instance_types = ["r5d.xlarge"]
node_volume_size    = 100

node_min_size                   = 1
node_max_size                   = 3
node_desired_size               = 1
node_max_unavailable_percentage = 100 # To ease testing
