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

variable "aws_regions" {
  type = list(string)
  default = [
    "us-west-2",
    "us-west-1"
  ]
}

resource "aws_s3_bucket" "registy-k8s-io-bucket" {
  for_each = toset(var.aws_regions)
  bucket   = "registy-k8s-io-bucket-${each.key}"
}

resource "aws_s3_bucket_ownership_controls" "registy-k8s-io-bucket" {
  for_each = aws_s3_bucket.registy-k8s-io-bucket
  bucket   = each.key

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_iam_user" "registy-k8s-io-bucket" {
  for_each = aws_s3_bucket.registy-k8s-io-bucket
  name     = "registy-k8s-io-bucket-${each.key}"
  path     = "/"
}

resource "aws_iam_access_key" "registy-k8s-io-bucket" {
  for_each = aws_s3_bucket.registy-k8s-io-bucket
  user     = aws_iam_user.registy-k8s-io-bucket[each.key].name
}

resource "aws_iam_user_policy" "registy-k8s-io-bucket-rw-bucket" {
  for_each = aws_s3_bucket.registy-k8s-io-bucket
  name     = "registy-k8s-io-bucket-${each.key}"
  user     = aws_iam_user.registy-k8s-io-bucket[each.key].name

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
        "Resource" : "${aws_s3_bucket.registy-k8s-io-bucket[each.key].arn}"
      },
      {
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Effect" : "Allow",
        "Resource" : "${aws_s3_bucket.registy-k8s-io-bucket[each.key].arn}/*"
      }
    ]
  })
}
