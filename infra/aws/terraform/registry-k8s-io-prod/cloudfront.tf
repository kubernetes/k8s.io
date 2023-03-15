/*
Copyright 2024 The Kubernetes Authors.

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

resource "aws_cloudfront_cache_policy" "no_cookies" {
  provider = aws.networking
  name     = "no-cookies"

  min_ttl     = 0
  default_ttl = 86400
  max_ttl     = 31536000 // 1 year

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Origin"]
      }
    }

    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  provider = aws.networking

  enabled         = true
  is_ipv6_enabled = true

  origin_group {
    origin_id = "registry-k8s-io-prod-image-layers"

    failover_criteria {
      status_codes = [403, 404, 500, 502]
    }


    member {
      origin_id = "registry-k8s-io-prod-us-east-2"
    }

    member {
      origin_id = "registry-k8s-io-prod-eu-west-1"
    }
  }

  origin {
    domain_name = "prod-registry-k8s-io-us-east-2.s3.us-east-2.amazonaws.com"
    origin_id   = "registry-k8s-io-prod-us-east-2"

    origin_shield {
      enabled              = true
      origin_shield_region = "us-east-2"
    }
  }

  origin {
    domain_name = "prod-registry-k8s-io-eu-west-1.s3.eu-west-1.amazonaws.com"
    origin_id   = "registry-k8s-io-prod-eu-west-1"

    origin_shield {
      enabled              = true
      origin_shield_region = "eu-west-1"
    }
  }

  default_cache_behavior {

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id = "registry-k8s-io-prod-image-layers"

    cache_policy_id = aws_cloudfront_cache_policy.no_cookies.id

    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}

# Enable real-time monitoring on cloud distribution
resource "aws_cloudfront_monitoring_subscription" "cloudfront" {
  provider = aws.networking

  distribution_id = aws_cloudfront_distribution.cloudfront_distribution.id

  monitoring_subscription {
    realtime_metrics_subscription_config {
      realtime_metrics_subscription_status = "Enabled"
    }
  }
}
