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
    description = "Default rule. Limit excessive usage."
    # apply rate limits last (rules are applied sequentially by priority)
    # clients not violating a rate limit rule that matches will be allowed
    # to reach the destination, so this rule should be last
    priority = "2147483647"

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
      # above this threshold we serve 429, currently 83/sec in a 30s window
      rate_limit_threshold {
        # NOTE: count cannot exceed 10,000
        # https://cloud.google.com/armor/docs/rate-limiting-overview
        # This is set to be like the ban limit, for a shorter time period
        # 83/second for 30s versus 83.33/second for two minutes
        # when users hit this, they receive 429 for the remainder of the 30s window
        count        = 2490
        interval_sec = 30
      }
      # if the user continues to exceed the rate limit, temp ban
      # otherwise users may ignore transient 429 and keep running right at the limit
      # clients that respect the 429 and backoff will not hit this
      # (or better yet, https://github.com/kubernetes/registry.k8s.io/blob/main/docs/mirroring/README.md)
      # this is only intended to signal to the most persistently high-QPS users that they should stop
      # when users hit this, they will receive 429 for the ban duration
      ban_threshold {
        count        = 10000
        interval_sec = 120
      }
      # one hour temp-ban (cloud armor maximum)
      ban_duration_sec = 3600
    }
  }

  // block all requests with obviously invalid paths at the edge
  // we support "/", "/privacy", and "/v2/.*" API, GET or HEAD

  rule {
    action      = "deny(404)"
    description = "Block invalid request paths."
    # apply this broad 404 for unexpected paths first
    priority = "1"
    match {
      expr {
        # allow:
        # our homepage info redirect: /
        # our privacy info redirect: /privacy
        # OCI ping: /v2
        # OCI content calls: /v2/<name>/(blobs|manifests)/<reference>
        # tag list: /v2/(<name>/tags|tags)/list
        # https://github.com/opencontainers/distribution-spec/blob/main/spec.md#endpoints
        # NOTE: AR doesn't support referrers API
        expression = "!request.path.matches('^/$|^/privacy$|^/v2/?$|^/v2/.+/blobs/.+$|^/v2/.+/manifests/.+$|^/v2/.*tags/list$')"
      }
    }
  }
}

