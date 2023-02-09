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

module "cloudtrail_kms" {
  providers = {
    aws = aws.security-eng
  }

  source      = "../modules/kms"
  name        = format("%s-%s", var.org_name, "cloudtrail_kms_key")
  description = "Encryption Key for CloudTrail logs"
  policy      = data.aws_iam_policy_document.kms_cloudtrail_policy.json
  tags        = var.tags
}

data "aws_iam_policy_document" "kms_cloudtrail_policy" {
  statement {
    sid    = "AllowAuditAdminManage"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.audit-account-id}:root"]
    }

    actions = ["kms:*"]

    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudTrailDecryptForSpecificRoles"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.audit-account-id}:role/Admin"]
    }

    actions = ["kms:Decrypt"]

    resources = ["*"]

    condition {
      test     = "Null"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = [false]
    }
  }

  statement {
    sid    = "AllowCloudTrailDescribe"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["kms:DescribeKey"]

    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudTrailEncrypt"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["kms:GenerateDataKey"]

    resources = [
      module.cloudtrail_kms.id
    ]

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = formatlist("arn:aws:cloudtrail:*:%s:trail/*", local.audit-account-id)
    }
  }
}


