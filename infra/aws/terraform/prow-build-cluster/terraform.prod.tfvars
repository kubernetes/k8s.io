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

aws_account_id = "468814281478"

eks_cluster_admins = [
  "bentheelder",
  "koray",
  "pprzekwa",
  "wozniakjan",
  "xmudrii"
]

eks_cluster_viewers = [
  "bentheelder",
  "koray",
  "pprzekwa",
  "wozniakjan",
  "xmudrii"
]

cluster_name               = "prow-build-cluster"
cluster_version            = "1.28"
cluster_autoscaler_version = "v1.28.0"

node_group_version_us_east_2a = "1.28"
node_group_version_us_east_2b = "1.28"
node_group_version_us_east_2c = "1.28"
node_group_version_stable     = "1.28"

node_instance_types_us_east_2a = ["r5ad.4xlarge"]
node_instance_types_us_east_2b = ["r5ad.4xlarge"]
node_instance_types_us_east_2c = ["r5ad.4xlarge"]
node_instance_types_stable     = ["r5ad.2xlarge"]

node_min_size_us_east_2a     = 0
node_max_size_us_east_2a     = 1
node_desired_size_us_east_2a = 0

node_min_size_us_east_2b     = 0
node_max_size_us_east_2b     = 1
node_desired_size_us_east_2b = 0

node_min_size_us_east_2c     = 0
node_max_size_us_east_2c     = 1
node_desired_size_us_east_2c = 0

node_desired_size_stable = 3

node_taints_stable = [
  {
    key    = "node-group"
    value  = "stable"
    effect = "NO_SCHEDULE"
  }
]
node_labels_stable = {
  "node-group" = "stable"
}

node_volume_size = 100

node_max_unavailable_percentage = 100 # To ease testing

bastion_install = true
public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAHl9be6hIi5xKA4rb5Y+TrQsyQ7nautEaZQDM5sLyN2DH8wzEe77w0KkPas77m3mzNUM3GC9PERTVPGahjlZxiB1N3M+a5HOS0rLhQxNZpbe+VRRpN683Mha3YVRAJlEanEodUR3O4gvb/9B7w/lq9PAw2anhu8tG9mCnN/nMTMOrJgS9vFvub78APKqR+lL80y298kCytwAbOxs+3qD/O4rZcln4Q83RZ0QXGgnp3lKZnnbMqAlIf+8UFljUIExuj+Bx+DinNpE5Ki29KwPJAvKzcR86xR7OZdLneYnVKGsHL3xSh2ax1m67zIKEFelQwZzuh3rEkRNqd4DAulfyW1Mhezl0xxSWpX/T+HtkyWqhUm5aGQ+KifVO/YKHbu+79aXgvWpzjVyJhmg0D+ZvZ4AyuHJo70Bbq3BWokPjQb7DWCZV1djeydHWTobZc+UALY/QnviDR6AYY+rstF3xcBq0E3zyZbkM2g7hchpl7fopAtC4fAgjy9+3k1VjSNNX7KOFUpU+nEF1eVP6GCI7o7Nmh7bRSYbrm88Ex1XtgX2d3q5lO2rfexAWVCT/xqo9Y5/BLKrZ4FPEBVFgxmewfjwAIRxQVlNsRWlw/COMwo9EbYEqY4fVpAcEWQtru0Jp297XvzebqzWk1r2ybBhhgQkvD1Is6H5uzDqJHFChxQ== kubernetes-sig-k8s-infra"
