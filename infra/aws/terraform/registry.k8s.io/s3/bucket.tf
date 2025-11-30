/*
Copyright 2022 The Kubernetes Authors.

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

resource "aws_s3_bucket" "registry-k8s-io" {
  bucket = "${var.prefix}registry-k8s-io-${var.region}"
  region = var.region
}

resource "aws_s3_bucket_public_access_block" "public" {
  bucket = aws_s3_bucket.registry-k8s-io.bucket
  region = var.region

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "registry-k8s-io-public-read" {
  bucket = aws_s3_bucket_public_access_block.public.id
  region = var.region

  policy = jsonencode({
    "Id" : "Public-Access",
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "s3:ListBucket",
        "Effect" : "Allow",
        "Resource" : "${aws_s3_bucket.registry-k8s-io.arn}",
        "Principal" : "*"
      },
      {
        "Action" : "s3:GetObject",
        "Effect" : "Allow",
        "Resource" : "${aws_s3_bucket.registry-k8s-io.arn}/*",
        "Principal" : "*"
      },
      {
        "Sid" : "AllowSSLRequestsOnly",
        "Action" : "s3:*",
        "Effect" : "Deny",
        "Resource" : "${aws_s3_bucket.registry-k8s-io.arn}/*",
        "Condition" : {
          "Bool" : {
            "aws:SecureTransport" : "false"
          }
        },
        "Principal" : "*"
      }
    ]
  })
}

resource "aws_s3_bucket_ownership_controls" "registry-k8s-io" {
  bucket = aws_s3_bucket.registry-k8s-io.bucket
  region = var.region

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
  depends_on = [
    aws_s3_bucket.registry-k8s-io,
    aws_s3_bucket_policy.registry-k8s-io-public-read
  ]
}

# Versioning must be enabled for S3 replication
resource "aws_s3_bucket_versioning" "registry-k8s-io" {
  bucket = aws_s3_bucket.registry-k8s-io.id
  region = var.region
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_replication_configuration" "registry-k8s-io" {
  count  = length(var.s3_replication_rules) > 0 ? 1 : 0
  region = var.region

  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.registry-k8s-io]

  role = var.s3_replication_iam_role_arn

  bucket = aws_s3_bucket.registry-k8s-io.id

  dynamic "rule" {
    for_each = var.s3_replication_rules

    content {
      id = rule.value.id

      status = rule.value.status

      # Set priority, filter and delete_marker_replication to use V2 schema for multiple 
      # destination bucket rules
      priority = rule.value.priority

      filter {}

      delete_marker_replication {
        status = "Enabled"
      }

      destination {
        bucket        = rule.value.destination_bucket_arn
        storage_class = rule.value.destination_bucket_storage_class

        metrics {
          status = "Enabled"
        }
      }
    }
  }
}
