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
  "pprzekwa",
  "wozniakjan",
  "xmudrii"
]

eks_cluster_viewers = [
  "pprzekwa",
  "wozniakjan",
  "xmudrii"
]

cluster_name               = "prow-build-cluster"
cluster_version            = "1.25"
cluster_autoscaler_version = "v1.25.0"

# Ubuntu EKS optimized AMI: https://cloud-images.ubuntu.com/aws-eks/
node_ami_blue            = "ami-07e8e7dddc8b3bad9"
node_instance_types_blue = ["r5ad.4xlarge"]

node_min_size_blue     = 0
node_max_size_blue     = 20
node_desired_size_blue = 0

node_ami_green            = "ami-07e8e7dddc8b3bad9"
node_instance_types_green = ["r5d.4xlarge"]

node_min_size_green     = 20
node_max_size_green     = 40
node_desired_size_green = 20

node_volume_size = 100

node_max_unavailable_percentage = 100 # To ease testing

public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAHl9be6hIi5xKA4rb5Y+TrQsyQ7nautEaZQDM5sLyN2DH8wzEe77w0KkPas77m3mzNUM3GC9PERTVPGahjlZxiB1N3M+a5HOS0rLhQxNZpbe+VRRpN683Mha3YVRAJlEanEodUR3O4gvb/9B7w/lq9PAw2anhu8tG9mCnN/nMTMOrJgS9vFvub78APKqR+lL80y298kCytwAbOxs+3qD/O4rZcln4Q83RZ0QXGgnp3lKZnnbMqAlIf+8UFljUIExuj+Bx+DinNpE5Ki29KwPJAvKzcR86xR7OZdLneYnVKGsHL3xSh2ax1m67zIKEFelQwZzuh3rEkRNqd4DAulfyW1Mhezl0xxSWpX/T+HtkyWqhUm5aGQ+KifVO/YKHbu+79aXgvWpzjVyJhmg0D+ZvZ4AyuHJo70Bbq3BWokPjQb7DWCZV1djeydHWTobZc+UALY/QnviDR6AYY+rstF3xcBq0E3zyZbkM2g7hchpl7fopAtC4fAgjy9+3k1VjSNNX7KOFUpU+nEF1eVP6GCI7o7Nmh7bRSYbrm88Ex1XtgX2d3q5lO2rfexAWVCT/xqo9Y5/BLKrZ4FPEBVFgxmewfjwAIRxQVlNsRWlw/COMwo9EbYEqY4fVpAcEWQtru0Jp297XvzebqzWk1r2ybBhhgQkvD1Is6H5uzDqJHFChxQ== kubernetes-sig-k8s-infra"
