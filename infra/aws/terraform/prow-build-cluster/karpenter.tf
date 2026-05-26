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

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.20"

  cluster_name = module.eks.cluster_name

  create_access_entry             = true
  create_pod_identity_association = true

  # HACK: https://github.com/terraform-aws-modules/terraform-aws-eks/issues/3512
  enable_inline_policy = true

  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "karpenter-nodes"
  node_iam_role_additional_policies = {
    # Allows accessing instances via AWS System Manager (SSM)
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    # Allows ecr:Describe* and ecr*Pull* actions
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  queue_name = "karpenter-queue"

  tags = local.tags

}
