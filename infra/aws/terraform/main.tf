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

resource "aws_kms_key" "kpromo-test-1" {
  description = "This key is used to encrypt bucket objects"
}

resource "aws_s3_bucket" "kpromo-test-1" {
  bucket = "kpromo-test-1"
  acl    = "private"

  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.kpromo-test-1.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
resource "aws_s3_bucket_ownership_controls" "kpromo-test-1" {
  bucket = aws_s3_bucket.kpromo-test-1.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_public_access_block" "kpromo-test-1" {
  bucket = aws_s3_bucket.kpromo-test-1.id

  block_public_acls   = true
  block_public_policy = true
}

resource "aws_iam_user" "kpromo-test-1" {
  name = "kpromo-test-1"
  path = "/"
}

resource "aws_iam_access_key" "kpromo-test-1" {
  user = aws_iam_user.kpromo-test-1.name
}

resource "aws_iam_user_policy" "kpromo-test-1-rw-bucket" {
  name = "kpromo-test-1"
  user = aws_iam_user.kpromo-test-1.name

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Effect" : "Allow",
        "Resource" : "${aws_s3_bucket.kpromo-test-1.arn}"
      },
      {
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Effect" : "Allow",
        "Resource" : "${aws_s3_bucket.kpromo-test-1.arn}/*"
      }
    ]
  })
}
