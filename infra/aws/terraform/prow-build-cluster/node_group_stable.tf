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

locals {
  node_group_stable = {
    name            = "managed-stable"
    description     = "EKS managed node group called stable used for stateful components"
    use_name_prefix = true

    cluster_version = var.node_group_version_stable

    taints = var.node_taints_stable
    labels = var.node_labels_stable

    subnet_ids = module.vpc.public_subnets

    min_size     = var.node_desired_size_stable
    max_size     = var.node_desired_size_stable
    desired_size = var.node_desired_size_stable

    iam_role_permissions_boundary = data.aws_iam_policy.eks_resources_permission_boundary.arn

    ami_type             = "BOTTLEROCKET_x86_64"
    platform             = "bottlerocket"
    bootstrap_extra_args = <<-EOT
      # Bottlerocket instances don't have SSH installed by default, but
      # there's the admin container that can be enabled and that comes
      # with SSH installed and enabled
      [settings.host-containers.admin]
      enabled = true

      # Bootstrap the instance using our bootstrap script embeded in a Docker image
      [settings.bootstrap-containers.bootstrap]
      source = "public.ecr.aws/q4o2z4d8/k8s-prow-bottlerocket:v0.0.2"
      mode = "always"
      essential = true

      [settings.kernel.sysctl]
      "fs.inotify.max_user_watches" = "1048576"
      "fs.inotify.max_user_instances" = "8192"
      "vm.min_free_kbytes" = "540672"
    EOT

    force_update_version = false
    update_config = {
      max_unavailable_percentage = var.node_max_unavailable_percentage
    }

    capacity_type  = "ON_DEMAND"
    instance_types = var.node_instance_types_stable

    ebs_optimized     = true
    enable_monitoring = true

    key_name = aws_key_pair.eks_nodes.key_name

    enclave_options = {
      enabled = true
    }

    timeouts = {
      update = "180m"
    }

    tags = merge(
      local.tags,
      var.additional_node_group_tags_stable
    )
  }
}
