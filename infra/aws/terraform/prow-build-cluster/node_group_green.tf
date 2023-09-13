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

locals {
  node_group_build_green = {
    name            = "build-managed-green"
    description     = "EKS managed node group called green used to facilitate node rotations/rollouts"
    use_name_prefix = true

    taints = var.node_taints_green
    labels = var.node_labels_green

    subnet_ids = module.vpc.public_subnets

    min_size     = var.node_min_size_green
    max_size     = var.node_max_size_green
    desired_size = var.node_desired_size_green

    iam_role_permissions_boundary = data.aws_iam_policy.eks_resources_permission_boundary.arn

    ami_id                     = var.node_ami_green
    enable_bootstrap_user_data = true

    force_update_version = false
    update_config = {
      max_unavailable_percentage = var.node_max_unavailable_percentage
    }

    pre_bootstrap_user_data = file("${path.module}/bootstrap/node_bootstrap_green.sh")

    capacity_type  = "ON_DEMAND"
    instance_types = var.node_instance_types_green

    ebs_optimized     = true
    enable_monitoring = true

    key_name = aws_key_pair.eks_nodes.key_name

    block_device_mappings = {
      # This must be sda1 in order to match the root volume,
      # otherwise a new volume is created.
      sda1 = {
        device_name = "/dev/sda1"
        ebs = {
          volume_size           = var.node_volume_size
          volume_type           = "gp3"
          iops                  = 16000 # Maximum for gp3 volume.
          throughput            = 1000  # Maximum for gp3 volume.
          encrypted             = false
          delete_on_termination = true
        }
      }
    }

    enclave_options = {
      enabled = true
    }

    timeouts = {
      update = "180m"
    }

    tags = merge(
      local.tags,
      local.auto_scaling_tags,
      var.additional_node_group_tags_green
    )
  }
}
