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
    action      = "throttle"
    description = "Default rule, throttle traffic"
    # apply rate limit first (rules are applied sequentially by priority)
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
      # This is comparable to the GCR limits from k8s.gcr.io
      rate_limit_threshold {
        count        = 5000
        interval_sec = 60
      }
    }

    preview = false
  }

  // block all requests with obviously invalid paths at the edge
  // we support "/", "/privacy", and "/v2/.*" API

  rule {
    action = "deny(404)"
    # apply this broad 404 for unexpected paths second
    priority = "1"
    match {
      expr {
        expression = "!request.path.match('(?:^/$)|(?:^/privacy$)|(?:^/v2/)')"
      }
    }
  }
}

