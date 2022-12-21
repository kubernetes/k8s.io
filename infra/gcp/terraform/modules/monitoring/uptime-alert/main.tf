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

resource "google_monitoring_uptime_check_config" "uptime_check" {
  project = var.project_id
  display_name = format("Uptime - %s", var.domain)

  http_check {
    mask_headers   = "false"
    path           = "/"
    port           = "443"
    request_method = "GET"
    use_ssl        = "true"
    validate_ssl   = "true"
  }

  monitored_resource {
    labels = {
      host       = var.domain
      project_id = var.project_id
    }

    type = "uptime_url"
  }

  period  = "60s"
  timeout = "10s"
}

resource "google_monitoring_alert_policy" "uptime_alert" {
  provider = google-beta
  project = var.project_id

  display_name          = "${var.domain}-uptime"
  combiner              = "OR"

  conditions {
    display_name = "Failure of uptime check on ${var.domain}"
    condition_threshold {
      comparison      = "COMPARISON_GT"
      duration        = "${var.failing_duration}s"
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.label.check_id=\"${var.domain}\" AND resource.type=\"uptime_url\""
      threshold_value = 1

      aggregations {
        alignment_period     = "300s"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.*"]
        per_series_aligner   = "ALIGN_NEXT_OLDER"
      }

      trigger {
        count   = 1
        percent = var.trigger_percent
      }
    }
  }

  documentation {
    content = var.documentation_text
  }

  notification_channels = var.notification_channels
  enabled = true

}

# SSL certificate expiring soon for uptime checks
resource "google_monitoring_alert_policy" "ssl_cert_expiration_alert" {
    project = var.project_id

  display_name = "SSL/TLS certificate expiration check"
  combiner     = "OR"

  conditions {
     display_name = "SSL Certificate for ${var.domain} expiring soon"
    condition_threshold {
      comparison      = "COMPARISON_LT"
      duration        = "600s"
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\" AND resource.type=\"uptime_url\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.uptime_check.uptime_check_id}\""
      # 2 weeks
      threshold_value = 15

      aggregations {
        alignment_period     = "1200s"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.*"]
        per_series_aligner   = "ALIGN_NEXT_OLDER"
      }

      trigger {
        count = 1
        percent = 0
      }
    }
  }

  documentation {
    content = "The SSL/TLS certificate for ${var.domain} is expiring in fewer than 15 days"
  }

    notification_channels = var.notification_channels

  enabled = true
}
