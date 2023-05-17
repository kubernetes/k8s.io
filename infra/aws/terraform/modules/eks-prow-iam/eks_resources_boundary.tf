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

// Bondary imposed on all IAM roles provisioned by EKSInfraAdmin role.
resource "aws_iam_policy" "eks_resources_permission_boundary" {
  name        = "EKSResourcesPermissionBoundary"
  path        = "/boundary/"
  description = "Permission boundary for roles created by EKSInfraAdmin."
  policy      = data.aws_iam_policy_document.eks_resources_permission_boundary_doc.json
  tags        = var.tags
}

data "aws_iam_policy_document" "eks_resources_permission_boundary_doc" {
  statement {
    sid = "AllowMany"

    effect = "Allow"

    actions = [
      "autoscaling:*",
      "ec2:*",
      "eks:*",
      "ecr:*",
      "iam:*",
      "kms:*",
      "logs:*",
      "sts:*",
      "s3:*"
    ]

    resources = ["*"]
  }

  statement {
    sid = "DenyEditPolicy"

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
