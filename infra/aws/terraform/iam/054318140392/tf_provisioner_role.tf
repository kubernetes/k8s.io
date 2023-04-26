data "aws_iam_user" "eks_admins" {
  count     = length(var.eks_admins)
  user_name = var.eks_admins[count.index]
}

data "aws_iam_policy_document" "tf_eks_provisioner_assume_doc" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = data.aws_iam_user.eks_admins[*].arn
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "tf_eks_provisioner" {
  name               = "TerraformEKSProvisioner"
  assume_role_policy = data.aws_iam_policy_document.tf_eks_provisioner_assume_doc.json

  tags = {
    Terraform = true
  }
}

resource "aws_iam_role_policy_attachment" "tf_eks_provisioner" {
  role       = aws_iam_role.tf_eks_provisioner.name
  policy_arn = aws_iam_policy.tf_eks_provisioner.arn
}

resource "aws_iam_policy" "tf_eks_provisioner" {
  name   = "TerraformEKSProvisioner"
  policy = data.aws_iam_policy_document.tf_eks_provisioner_doc.json

  tags = {
    Terraform = true
  }
}

data "aws_iam_policy_document" "tf_eks_provisioner_doc" {
  statement {
    sid       = "TerraformEKSProvisioner"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeEgressOnlyInternetGateways",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcClassicLink",
      "ec2:DescribeVpcClassicLinkDnsSupport",
      "ec2:DescribeVpcs",
      "eks:DescribeAddon",
      "eks:DescribeAddonVersions",
      "eks:DescribeCluster",
      "eks:DescribeNodegroup",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:GetUser",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListAliases",
      "kms:ListResourceTags",
      "logs:DescribeLogGroups",
      "logs:ListTagsLogGroup",
      "s3:GetObject",
      "s3:ListBucket",
      "sts:AssumeRole"
    ]
  }
}
