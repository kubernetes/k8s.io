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
  version = "~> 20.20"

  cluster_name = module.eks.cluster_name

  create_access_entry             = true
  create_pod_identity_association = true

  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "karpenter-nodes"
  enable_v1_permissions         = true
  # Allows accessing instances via AWS System Manager (SSM)
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  queue_name = "karpenter-queue"

  tags = local.tags

}
