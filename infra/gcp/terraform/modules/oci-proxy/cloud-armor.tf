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


  rule {
    action   = "deny(403)"
    priority = "910"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('methodenforcement-v33-stable', {'sensitivity': 1})"
      }
    }
    description = "Method enforcement"

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "900"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('protocolattack-v33-stable', {'sensitivity': 3, 'opt_out_rule_ids': ['owasp-crs-v030301-id921170-protocolattack']})"
      }
    }
    description = "Protocol Attack"

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "920"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('scannerdetection-v33-stable', {'sensitivity': 1})"
      }
    }
    description = "Scanner detection"

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "990"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v33-stable', {'sensitivity': 1})"
      }
    }
    description = "Cross-site scripting (XSS)"

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "960"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('lfi-v33-stable', {'sensitivity': 1})"
      }
    }
    description = "Local file inclusion (LFI)"

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "930"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-stable')"
      }
    }

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "940"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('rfi-v33-stable', {'sensitivity': 2})"
      }
    }
    description = "Remote file inclusion (RFI)"

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "950"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sessionfixation-v33-stable', {'sensitivity': 1})"
      }
    }
    description = "Session fixation"

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "980"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('php-v33-stable', {'sensitivity': 3})"
      }
    }
    description = "PHP"

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "1010"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('cve-canary')"
      }
    }
    description = "CVEs and other vulnerabilities"

    preview = false
  }

  # Permit all other traffic, with rate limits
  rule {
    action      = "throttle"
    description = "Default rule, throttle traffic"
    priority    = "2147483647"

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
}

