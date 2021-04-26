/*

This file contains 
- defined budget for this project
- notification channel when threshold is reached
*/

// https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget
resource "google_billing_budget" "budget" {
  billing_account = data.google_billing_account.account.id
  display_name    = "Billing Budget for ${google_project.project.id}"

  budget_filter {
    projects = ["projects/${google_project.project.number}"]
  }

  amount {
    specified_amount {
      units = "1000"
    }
  }

  threshold_rules {
    threshold_percent = 0.9 // Threshold of 90% of the budget
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.wg_k8s_infra_leads.id,
    ]
    disable_default_iam_recipients = true
  }
}

resource "google_monitoring_notification_channel" "wg_k8s_infra_leads" {
  display_name = "Example Notification Channel"
  type         = "email"

  labels = {
    email_address = "wg-k8s-infra-leads@kubernetes.io"
  }
}
