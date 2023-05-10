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

// NOTE: compare this file to ./../k8s-infra-oci-proxy-prod/main.tf
locals {
  project_id = "k8s-infra-oci-proxy"
}

module "oci-proxy" {
  source = "../modules/oci-proxy"
  // ***** production vs staging variables inputs *****
  // NOTE: digest should typically be overridden to the latest when deploying staging
  // For now this will be done with a small wrapper script
  // Otherwise it will default to the version used in prod
  digest               = var.digest
  domain               = "registry-sandbox.k8s.io"
  project_id           = local.project_id
  service_account_name = "oci-proxy-sandbox"
  // we increase this in staging, but not in production
  // we already get a lot of info from built-in cloud run logs
  verbosity = "3"
  // Manually created. Monitoring channels can't be created with Terraform.
  // See: https://github.com/hashicorp/terraform-provider-google/issues/1134
  notification_channel_id = "3237876589275698022"
}
