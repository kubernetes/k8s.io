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


# This file contains the Cloud Armor policies

resource "google_compute_security_policy" "cloud-armor" {
  project = var.project_id
  name    = "security-policy-oci-proxy"

  # apply rate limits
  rule {
    action      = "rate_based_ban"
    description = "Limit excessive usage"
    # apply rate limits first (rules are applied sequentially by priority)
    # https://cloud.google.com/armor/docs/security-policy-overview#eval-order
    priority = "0"

    match {
      config {
        src_ip_ranges = ["*"]
      }
      versioned_expr = "SRC_IPS_V1"
    }

    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      # TODO: revisit these values
      # above this threshold we serve 429, currently ~83/sec in a 1 minute window
      rate_limit_threshold {
        # NOTE: count cannot exceed 10,000
        # https://cloud.google.com/armor/docs/rate-limiting-overview
        count        = 5000
        interval_sec = 60
      }
      # if the user continues to exceed the rate limit, temp ban
      # otherwise users may ignore transient 429 and keep running right at the limit
      # clients that respect the 429 and backoff will not hit this
      # (or better yet, https://github.com/kubernetes/registry.k8s.io/blob/main/docs/mirroring/README.md)
      ban_threshold {
        count        = 10000
        interval_sec = 120
      }
      ban_duration_sec = 1800
    }
  }

  // block all requests with obviously invalid paths at the edge
  // we support "/", "/privacy", and "/v2/.*" API, GET or HEAD

  rule {
    action = "deny(404)"
    # apply this broad 404 for unexpected paths second
    priority = "1"
    match {
      expr {
        # allow:
        # our homepage info redirect: /
        # our privacy info redirect: /privacy
        # OCI ping: /v2
        # OCI pull / list calls: /v2/<name>/(blobs|manifests|tags)/<reference>
        # https://github.com/opencontainers/distribution-spec/blob/main/spec.md#endpoints
        # NOTE: AR doesn't support referrers API
        expression = "!request.path.matches('(?:^/?$)|(?:^/privacy$)|(?:^/v2/?$)|(?:^/v2/.+/(:?blobs|manifests|tags)/.+$)')"
      }
    }
  }

  # you must have a default rule with max int32 priority
  # (IE applied last after every other rule)
  # this just allows traffic not caught by any other rule
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule"
  }
}

