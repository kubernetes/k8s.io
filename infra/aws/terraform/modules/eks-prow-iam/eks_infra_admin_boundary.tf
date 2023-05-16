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

# TODO(pkprzekwas): remove after replacing boundary name in EKS cluster roles and applying changes.
resource "aws_iam_policy" "provisioner_permission_boundary" {
  name        = "ProvisionerPermissionBoundary"
  description = "Permission boundary for terraform operator roles."
  policy      = data.aws_iam_policy_document.eks_resources_permission_boundary_doc.json
  tags        = var.tags
}

// Imposes setting EKSResourcesPermissionBoundary on all IAM roles provisioned with its usage.
resource "aws_iam_policy" "eks_infra_admin_permission_boundary" {
  name        = "EKSInfraAdminPermissionBoundary"
  description = "Permission boundary for EKSInfra* roles."
  policy      = data.aws_iam_policy_document.eks_infra_admin_permission_boundary_doc.json
  tags        = var.tags
}

data "aws_iam_policy_document" "eks_infra_admin_permission_boundary_doc" {
  statement {
    sid = "EKSInfraAdminPermissionBoundary"

    effect = "Allow"

    actions = [
      "*"
    ]

    # At some point we'll start narrowing above with:

    # actions = [
    #   "ec2:*",
    #   "eks:*",
    #   "ecr:*",
    #   "iam:*",
    #   "kms:*",
    #   "logs:*",
    #   "sts:*",
    #   "s3:*"
    # ]

    resources = ["*"]
  }

  statement {
    sid       = "CreateOrChangeOnlyWithBoundary"
    effect    = "Deny"
    resources = ["*"]

    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:CreateServiceLinkedRole",
      "iam:PutRolePolicy",
      "iam:PutRolePermissionsBoundary",
    ]

    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values = [
        aws_iam_policy.eks_resources_permission_boundary.arn
      ]
    }
  }

  statement {
    sid = "DenyEditOwnBoundary"

    effect = "Deny"

    actions = [
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion"
    ]

    resources = [
      "arn:aws:iam::${local.account_id}:policy/EKSInfraAdminPermissionBoundary"
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
