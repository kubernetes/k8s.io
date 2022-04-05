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
  bucket = "registry-k8s-io-${var.region}"
}

resource "aws_s3_bucket_ownership_controls" "registry-k8s-io" {
  bucket = aws_s3_bucket.registry-k8s-io.bucket

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_iam_user_policy" "registry-k8s-io-rw" {
  name = "registry-k8s-io-access"
  user = aws_iam_user.registry-k8s-io-access.name

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
        "Resource" : "${aws_s3_bucket.registry-k8s-io.arn}"
      },
      {
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Effect" : "Allow",
        "Resource" : "${aws_s3_bucket.registry-k8s-io.arn}/*"
      }
    ]
  })
}

# resource "aws_s3_bucket_inventory" "sync-from-mgmnt" {
#   bucket = var.mgmnt-bucket
#   name   = "${aws_s3_bucket.registry-k8s-io.arn}-from-mgmnt"

#   included_object_versions = "All"

#   schedule {
#     frequency = "Daily"
#   }

#   destination {
#     bucket {
#       format     = "ORC"
#       bucket_arn = aws_s3_bucket.registry-k8s-io.arn
#     }
#   }
# }
