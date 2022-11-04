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

resource "google_monitoring_notification_channel" "emails" {
  display_name = "k8s-infra-alerts@kubernetes.io"
  project      = google_project.project.project_id
  type         = "email"
  labels = {
    email_address = "k8s-infra-alerts@kubernetes.io"
  }
}

module "alerts" {
  project_id         = google_project.project.project_id
  source             = "../modules/monitoring/uptime-alert"
  documentation_text = "${var.domain} is down"
  domain             = var.domain

  notification_channels = [
    # Manually created. Monitoring channels can't be created with Terraform.
    # See: https://github.com/hashicorp/terraform-provider-google/issues/1134
    "${google_project.project.id}/notificationChannels/15334306215710275143",
    google_monitoring_notification_channel.emails.name,
  ]
}
