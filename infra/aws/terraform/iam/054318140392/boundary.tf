resource "aws_iam_policy" "tf_boundary" {
  name        = "TerraformPermissionBoundary"
  description = "Permission boundary for terraform operator roles."
  policy      = data.aws_iam_policy_document.tf_boundary_doc.json

  tags = {
    Terraform = true
  }
}

data "aws_iam_policy_document" "tf_boundary_doc" {
  statement {
    sid = "TFPermissionBoundary"

    effect = "Allow"

    actions = [
      "ec2:*",
      "eks:*",
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
      "arn:aws:iam::${local.account_id}:policy/TerraformPermissionBoundary"
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

  # An example of protecting a single S3 bucket.
  statement {
    sid = "DenyProdS3BucketAccess"

    effect = "Deny"

    actions = [
      "s3:*"
    ]

    resources = [
      "arn:aws:s3:::prod",
      "arn:aws:s3:::prod/*"
    ]
  }
}
