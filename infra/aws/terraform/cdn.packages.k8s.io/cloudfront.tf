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

locals {
  s3_origin_id = "${local.prefix}cdn.packages.k8s.io-s3-origin"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  # CachingOptmizied is recommended for S3
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "cdn_packages_k8s_io" {
  name                              = "${local.prefix}cdn.packages.k8s.io"
  description                       = "Control policy for cdn.packages.k8s.io"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn_packages_k8s_io" {
  origin {
    origin_id = local.s3_origin_id

    domain_name              = aws_s3_bucket.cdn_packages_k8s_io.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cdn_packages_k8s_io.id

    origin_path = ""

    connection_attempts = 3
    connection_timeout  = 10
  }

  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2"
  default_root_object = ""
  comment             = "CloudFront used by OpenBuildService (OBS) as a mirror"

  aliases = ["${local.prefix}cdn.packages.k8s.io"]

  web_acl_id = aws_wafv2_web_acl.cdn_packages_k8s_io.arn

  default_cache_behavior {
    target_origin_id = local.s3_origin_id

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id

    compress               = true
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cdn_packages_k8s_io.arn
    ssl_support_method  = "sni-only"
  }

  depends_on = [
    aws_acm_certificate.cdn_packages_k8s_io,
    aws_cloudfront_origin_access_control.cdn_packages_k8s_io,
    aws_wafv2_web_acl.cdn_packages_k8s_io,
    aws_s3_bucket.cdn_packages_k8s_io,
  ]

  tags = local.tags
}
