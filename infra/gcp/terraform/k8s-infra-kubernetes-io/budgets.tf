/*
Copyright 2021 The Kubernetes Authors.

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

data "google_monitoring_notification_channel" "sig_k8s_infra_leads" {
  project = data.google_project.kubernetes_public.project_id
  display_name = "sig-k8s-infra-leads@kubernetes.io"
}

data "google_project" "k8s_infra_sandbox_capg" {
  project_id = "k8s-infra-sandbox-capg"
}

resource "google_billing_budget" "capg_budget" {
  billing_account = data.google_billing_account.account.billing_account
  display_name = "k8s-infra-sandbox-capg"
  budget_filter {
    # calendar_period = "MONTH" # TODO: terraform doesn't support this?
    projects = [ "projects/${data.google_project.k8s_infra_sandbox_capg.number}" ]
    # exclude promotions, which is where our credits come from, since that zeros out cost
    credit_types_treatment = "INCLUDE_SPECIFIED_CREDITS"
    credit_types           = [
        "SUSTAINED_USAGE_DISCOUNT",
        "DISCOUNT",
        "COMMITTED_USAGE_DISCOUNT",
        "FREE_TIER",
        "COMMITTED_USAGE_DISCOUNT_DOLLAR_BASE",
        "SUBSCRIPTION_BENEFIT",
    ]
  }
  amount {
    specified_amount {
      currency_code = "USD"
      units = "5000"
    }
  }
  all_updates_rule {
    # Don't send to users with Billing Account Administrators and
    # Billing Account Users IAM roles for the billing account
    disable_default_iam_recipients = true
    monitoring_notification_channels = [
      data.google_monitoring_notification_channel.sig_k8s_infra_leads.name
    ]
  }
  dynamic "threshold_rules" {
    for_each = toset([0.2, 0.5, 0.9, 1.0])
    content {
      threshold_percent = threshold_rules.value
    }
  }
}

resource "google_billing_budget" "k8s_infra" {
  billing_account = data.google_billing_account.account.billing_account
  display_name = "k8s-infra-monthly"
  budget_filter {
    # calendar_period = "MONTH" # TODO: terraform doesn't support this?
    # exclude promotions, which is where our credits come from, since that zeros out cost
    credit_types_treatment = "INCLUDE_SPECIFIED_CREDITS"
    credit_types           = [
        "SUSTAINED_USAGE_DISCOUNT",
        "DISCOUNT",
        "COMMITTED_USAGE_DISCOUNT",
        "FREE_TIER",
        "COMMITTED_USAGE_DISCOUNT_DOLLAR_BASE",
        "SUBSCRIPTION_BENEFIT",
    ]
  }
  amount {
    specified_amount {
      currency_code = "USD"
      units = "250000" # 3M/yr / 12mo
    }
  }
  all_updates_rule {
    # Don't send to users with Billing Account Administrators and
    # Billing Account Users IAM roles for the billing account
    disable_default_iam_recipients = true
    monitoring_notification_channels = [
      data.google_monitoring_notification_channel.sig_k8s_infra_leads.name
    ]
  }
  dynamic "threshold_rules" {
    for_each = toset([0.9, 1.0])
    content {
      threshold_percent = threshold_rules.value
    }
  }
}
