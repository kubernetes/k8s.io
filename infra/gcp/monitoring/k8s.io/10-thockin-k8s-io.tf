locals {
  project_id       = "kubernetes-public"
  monitored_domain = "thockin-test1.k8s.io"
}

// Needed to import the notification channel
provider "google" {
  project = local.project_id
}

// Manual step: Create a StackDriver alert channel pointing to a channel in Slack
// It will select the channel here by its display name
data "google_monitoring_notification_channel" "alertchannel" {
  type = "slack"
  labels = {
    "channel_name" = "#k8s-infra-alerts"
  }
}

// We can turn this into a module and then add then standardize the resource display names
resource "google_monitoring_uptime_check_config" "uptime_check" {
  display_name = "${local.monitored_domain} https"
  timeout      = "5s"
  period       = "300s"

  http_check {
    path         = "/"
    port         = "443"
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = local.project_id
      // Host to be verified (1)
      host = local.monitored_domain
    }
  }
}


resource "google_monitoring_alert_policy" "cert_expiration_alert" {
  combiner              = "OR"
  display_name          = "${local.monitored_domain} certificate monitor"
  enabled               = true
  notification_channels = [data.google_monitoring_notification_channel.alertchannel.name]
  project               = local.project_id

  conditions {
    display_name = "${local.monitored_domain} expiration days is below the defined threshold"

    condition_threshold {
      comparison = "COMPARISON_LT"

      // = 5 minutes failing! may be increased or reduced
      duration = "300s"

      // resource.label.host should be changed accordingly with the uptime check created before (1)
      filter = "metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\" resource.type=\"uptime_url\" resource.label.\"host\"=\"${local.monitored_domain}\" metric.label.\"checker_location\"=\"usa-iowa\""

      // Number in days until the cert expires that should trigger an alert
      threshold_value = 15

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }
}

