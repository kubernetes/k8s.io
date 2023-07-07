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

resource "aws_iam_policy" "eks_destroy" {
  name_prefix = "EKSClusterDestroyer"
  path        = "/terraform/eks/"
  policy      = data.aws_iam_policy_document.eks_destroy.json
  tags        = var.tags
}

data "aws_iam_policy_document" "eks_destroy" {
  statement {
    sid       = "AllowEKSDelete"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "acm:DeleteCertificate",
      "autoscaling:DeleteTags",
      "ec2:DeleteEgressOnlyInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteLaunchTemplateVersion",
      "ec2:DeleteNatGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteVpc",
      "ec2:DeleteTags",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateAddress",
      "ec2:DisassociateRouteTable",
      "ec2:DisassociateVpcCidrBlock",
      "ec2:ReleaseAddress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteKeyPair",
      "ec2:TerminateInstances",
      "eks:DeleteAddon",
      "eks:DeleteCluster",
      "eks:DeleteNodegroup",
      "eks:UntagResource",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeletePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DeleteRolePermissionsBoundary",
      "iam:DetachRolePolicy",
      "iam:DeletePolicyVersion",
      "iam:UntagRole",
      "kms:DeleteAlias",
      "kms:ScheduleKeyDeletion",
      "logs:DeleteLogGroup",
    ]
  }

  statement {
    sid = "DenyDeleteBoundary"

    effect = "Deny"

    actions = [
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRolePermissionsBoundary",
      "iam:DetachRolePolicy",
    ]

    resources = [
      aws_iam_policy.eks_resources_permission_boundary.arn
    ]
  }
}
