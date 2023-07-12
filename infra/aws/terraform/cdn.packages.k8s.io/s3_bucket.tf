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

resource "aws_s3_bucket" "cdn_packages_k8s_io" {
  bucket = "${local.prefix}cdn-packages-k8s-io-${data.aws_region.current.name}"

  tags = local.tags
}

# This object ownership control ensures that ACLs are disabled for the bucket.
resource "aws_s3_bucket_ownership_controls" "cdn_packages_k8s_io" {
  bucket = aws_s3_bucket.cdn_packages_k8s_io.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }

  depends_on = [
    aws_s3_bucket.cdn_packages_k8s_io,
  ]
}

resource "aws_s3_bucket_versioning" "cdn_packages_k8s_io" {
  bucket = aws_s3_bucket.cdn_packages_k8s_io.id

  versioning_configuration {
    status = "Disabled"
  }

  depends_on = [
    aws_s3_bucket.cdn_packages_k8s_io,
  ]
}

resource "aws_s3_bucket_policy" "cdn_packages_k8s_io_cloudfront_read" {
  bucket = aws_s3_bucket.cdn_packages_k8s_io.bucket

  # Source: https://docs.aws.amazon.com/whitepapers/latest/secure-content-delivery-amazon-cloudfront/s3-origin-with-cloudfront.html
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : {
      "Sid" : "AllowCloudFrontServicePrincipalReadOnly",
      "Effect" : "Allow",
      "Principal" : {
        "Service" : "cloudfront.amazonaws.com"
      },
      "Action" : "s3:GetObject",
      "Resource" : "arn:aws:s3:::${aws_s3_bucket.cdn_packages_k8s_io.bucket}/*",
      "Condition" : {
        "StringEquals" : {
          "AWS:SourceArn" : "arn:aws:cloudfront::${local.account_id}:distribution/${aws_cloudfront_distribution.cdn_packages_k8s_io.id}"
        }
      }
    }
  })

  depends_on = [
    aws_s3_bucket.cdn_packages_k8s_io,
    aws_cloudfront_distribution.cdn_packages_k8s_io,
  ]
}
