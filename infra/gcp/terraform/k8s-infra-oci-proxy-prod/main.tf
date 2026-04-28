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

// NOTE: compare this file to ./../k8s-infra-oci-proxy/main.tf
locals {
  project_id = "k8s-infra-oci-proxy-prod"
}

module "oci-proxy" {
  source = "../modules/oci-proxy"
  // ***** production vs staging variables inputs *****
  //
  // explicitly using default digest here vs staging which overrides it
  digest               = null
  domain               = "registry.k8s.io"
  project_id           = local.project_id
  service_account_name = "oci-proxy-prod"
  // we increase this in staging, but not in production
  // we already get a lot of info from built-in cloud run logs
  verbosity = "0"
  // Manually created. Monitoring channels can't be created with Terraform.
  // See: https://github.com/hashicorp/terraform-provider-google/issues/1134
  notification_channel_id = "15334306215710275143"
}

// we only sink logs to bigquery in production
resource "google_logging_project_sink" "bigquery_sink" {
  project     = local.project_id
  name        = "registry-k8s-io-logs-sink"
  destination = "bigquery.googleapis.com/projects/k8s-infra-public-pii/datasets/registry_k8s_io_logs"

  bigquery_options {
    use_partitioned_tables = false
  }

  unique_writer_identity = true

  filter = "resource.type = \"cloud_run_revision\" AND log_name= \"projects/${local.project_id}/logs/run.googleapis.com%2Frequests\""
}
