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

resource "aws_iam_policy" "eks_apply" {
  name_prefix = "EKSClusterApplier"
  path        = "/terraform/eks/"
  policy      = data.aws_iam_policy_document.eks_apply.json
  tags        = var.tags
}

# WARNING/TODO: This policy can allow escalating priviliges and removing deny rules!!!
# See the following comments for more details:
# - https://github.com/kubernetes/k8s.io/pull/5113#discussion_r1164205616
# - https://github.com/kubernetes/k8s.io/pull/5113#discussion_r1164206798
data "aws_iam_policy_document" "eks_apply" {
  statement {
    sid       = "AllowEKSCreateOrUpadate"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "acm:AddTagsToCertificate",
      "acm:RequestCertificate",
      "autoscaling:CreateOrUpdateTags",
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AssociateVpcCidrBlock",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateEgressOnlyInternetGateway",
      "ec2:CreateInternetGateway",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:ModifyLaunchTemplate",
      "ec2:CreateNatGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RunInstances",
      "ec2:ModifyInstanceAttribute",
      "ec2:TerminateInstances",
      "ec2:ImportKeyPair",
      "eks:CreateAddon",
      "eks:CreateCluster",
      "eks:CreateNodegroup",
      "eks:TagResource",
      "eks:UpdateAddon",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:PassRole",
      "iam:TagOpenIDConnectProvider",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:UpdateAssumeRolePolicy",
      "kms:CreateAlias",
      "kms:CreateGrant",
      "kms:CreateKey",
      "kms:EnableKeyRotation",
      "kms:ListAliases",
      "kms:ListResourceTags",
      "kms:PutKeyPolicy",
      "kms:TagResource",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup",
      "s3:PutObject",
      # TODO(xmudrii-ubuntu): remove after removing ECR repo
      "ecr-public:*"
    ]
  }

  // This statement effectively enforces EKSResourcesPermissionBoundary on IAM resources
  // created with this policy.
  statement {
    sid = "AllowCreateOnlyWithBoundary"

    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:CreateUser",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values = [
        aws_iam_policy.eks_resources_permission_boundary.arn
      ]
    }
  }

  statement {
    sid       = "AllowChangeOnlyWithEKSResourceBoundary"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "iam:AttachRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:PutRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:AttachUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:DetachUserPolicy",
      "iam:PutUserPolicy",
      "iam:PutUserPermissionsBoundary",
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values = [
        aws_iam_policy.eks_resources_permission_boundary.arn
      ]
    }
  }

  statement {
    sid = "DenyEditBoundaries"

    effect = "Deny"

    actions = [
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion"
    ]

    resources = [
      "arn:aws:iam::${local.account_id}:policy/boundary/*"
    ]
  }

  statement {
    sid = "DenyLeaveOrganisation"

    effect = "Deny"

    actions = [
      "organizations:LeaveOrganization"
    ]

    resources = ["*"]
  }
}
