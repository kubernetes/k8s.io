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

data "aws_iam_policy_document" "cloudtrail_bucket" {
  provider = aws.security-eng

  statement {
    sid     = "AWSCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    resources = [
      aws_s3_bucket.cloutrail_logs.arn
    ]

    condition {
      variable = "aws:SourceArn"
      test     = "ArnEquals"
      values   = [aws_cloudtrail.organizational_trail.arn]
    }
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    resources = [
      "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudtrail.organizational_trail.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "Null"
      values   = ["true"]
      variable = "s3:x-amz-server-side-encryption"
    }
  }
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  provider            = aws.logging
  bucket              = local.cloudtrail_trail_name
  force_destroy       = true
  object_lock_enabled = true

  tags = merge({
    env     = "Audit"
    service = "CloudTrail",
    role    = "S3"
  }, var.tags)
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail_logs.id
  policy   = data.aws_iam_policy_document.cloudtrail_assume_role.json
}
