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

data "google_project" "project" {
  project_id = "kubernetes-public"
}

// Slack channel on https://kubernetes.slack.com used for alerting 
data "google_monitoring_notification_channel" "slack_alerts" {
  display_name = "#k8s-infra-alerts"
  project      = data.google_project.project.project_id
}

resource "google_monitoring_notification_channel" "email" {
  for_each = toset([
    "steering@kubernetes.io",
    "sig-k8s-infra-leads@kubernetes.io",
  ])
  display_name = each.value
  project      = data.google_project.project.project_id
  type         = "email"
  labels = {
    email_address = each.value
  }
}

resource "google_monitoring_dashboard" "gcs_dashboard" {
  project        = data.google_project.project.project_id
  dashboard_json = file("./dashboards/cloud-storage-monitoring.json")
}
