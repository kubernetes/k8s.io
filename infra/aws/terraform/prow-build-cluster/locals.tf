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
  root_account_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"

  # TODO(xmudrii): This is a temporary condition. To be deleted after making canary cluster a build cluster.
  configure_prow = var.cluster_name == "prow-build-cluster"

  aws_cli_args = [
    "eks",
    "get-token",
    "--cluster-name",
    module.eks.cluster_name,
    "--role-arn",
    data.aws_iam_role.tf_prow_provisioner.arn
  ]

  tags = {
    Cluster = var.cluster_name
  }

  auto_scaling_tags = {
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"             = true
  }

  node_group_tags = merge(local.tags, local.auto_scaling_tags)

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  aws_auth_roles = concat(
    local.configure_prow ? [
      # Allow access to the Prow-EKS-Admin IAM role (used by Prow directly).
      {
        "rolearn"  = aws_iam_role.eks_admin[0].arn
        "username" = "eks-admin"
        "groups" = [
          "eks-prow-cluster-admin"
        ]
      }
    ] : [],
    [
      # Allow admin access to the TFProwClusterProvisioner IAM role (used with assume role with other IAM accounts).
      {
        "rolearn"  = data.aws_iam_role.tf_prow_provisioner.arn
        "username" = "eks-cluster-admin"
        "groups" = [
          "eks-cluster-admin"
        ]
      },
      # Allow view access to the TFProwClusterViewer IAM role (used with assume role with other IAM accounts).
      {
        "rolearn"  = aws_iam_role.iam_cluster_viewer.arn
        "username" = "eks-cluster-viewer"
        "groups" = [
          "eks-cluster-viewer"
        ]
      }
    ]
  )
}
