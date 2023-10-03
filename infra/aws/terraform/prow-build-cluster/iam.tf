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

# We allow Prow Pods with specific service acccounts on the a particular cluster to assume this role.
resource "aws_iam_role" "eks_prow_admin" {
  count = local.configure_prow ? 1 : 0

  name                 = "Prow-EKS-Admin"
  max_session_duration = 43200
  permissions_boundary = data.aws_iam_policy.eks_resources_permission_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : aws_iam_openid_connect_provider.k8s_prow[0].arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "container.googleapis.com/v1/projects/k8s-prow/locations/us-central1-f/clusters/prow:sub" : [
              // https://github.com/kubernetes/test-infra/tree/master/config/prow/cluster
              // all services that load kubeconfig should be listed here
              "system:serviceaccount:default:deck",
              "system:serviceaccount:default:config-bootstrapper",
              "system:serviceaccount:default:crier",
              "system:serviceaccount:default:sinker",
              "system:serviceaccount:default:prow-controller-manager",
              "system:serviceaccount:default:hook"
            ]
          }
        }
      }
    ]
  })
}

# Roles defined below MUST NOT have any policies attached to them.
# Those are used in aws-auth config map and are dedicated to interact with EKS cluster via kubeconfig.
resource "aws_iam_role" "eks_cluster_viewer" {
  name                 = "EKSClusterViewer"
  description          = "IAM role used to delegate access to ${var.cluster_name}"
  permissions_boundary = data.aws_iam_policy.eks_resources_permission_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : data.aws_iam_user.eks_cluster_viewers[*].arn
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {}
      }
    ]
  })
}

resource "aws_iam_role" "eks_cluster_admin" {
  name                 = "EKSClusterAdmin"
  description          = "IAM role used to delegate access to ${var.cluster_name}"
  permissions_boundary = data.aws_iam_policy.eks_resources_permission_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : data.aws_iam_user.eks_cluster_admins[*].arn
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {}
      }
    ]
  })
}
