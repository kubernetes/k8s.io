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

resource "aws_s3_bucket" "cloudtrail_logs" {
  provider      = aws.logging
  bucket        = local.cloudtrail_bucket_name
  force_destroy = true

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

resource "aws_s3_bucket_policy" "cloudtrail_access" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail_logs.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.cloudtrail_logs.arn}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": [
              "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_organizations_organization.current.master_account_id}/*",
              "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_organizations_organization.current.id}/*"
            ],
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}
