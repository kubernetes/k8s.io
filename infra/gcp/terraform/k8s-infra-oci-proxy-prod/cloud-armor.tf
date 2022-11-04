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
  project = google_project.project.project_id
  name    = "security-policy-oci-proxy"


  rule {
    action   = "deny(403)"
    priority = "910"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('methodenforcement-stable')"
      }
    }

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "900"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('protocolattack-stable')"
      }
    }

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "920"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-stable')"
      }
    }

    preview = false
  }


  rule {
    action   = "deny(403)"
    priority = "990"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
  }

  rule {
    action   = "deny(403)"
    priority = "970"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "960"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-stable')"
      }
    }

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
        expression = "evaluatePreconfiguredExpr('rfi-stable')"
      }
    }

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "950"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sessionfixation-stable')"
      }
    }

    preview = false
  }

  rule {
    action   = "deny(403)"
    priority = "980"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('php-stable')"
      }
    }

    preview = false
  }

  # Reject all traffic that hasn't been whitelisted.
  rule {
    action      = "allow"
    description = "Default rule, higher priority overrides it"
    priority    = "2147483647"

    match {
      config {
        src_ip_ranges = ["*"]
      }
      versioned_expr = "SRC_IPS_V1"
    }

    preview = false
  }
}

