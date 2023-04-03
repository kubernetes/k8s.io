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
  project_id           = "k8s-infra-oci-proxy"
  service_account_name = "oci-proxy-sandbox"
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
  service_account_name = local.service_account_name
  // we increase this in staging, but not in production
  // we already get a lot of info from build-in cloud run logs
  verbosity = "3"
  // Manually created. Monitoring channels can't be created with Terraform.
  // See: https://github.com/hashicorp/terraform-provider-google/issues/1134
  notification_channel_id = "3237876589275698022"
}

// Currently we only do this for staging, prod is manual deployed by admins
//
// Ensure gcb-builder can auto-deploy registry-sandbox.k8s.io
//
// TODO: create a dedicated service account for auto-deployment
data "google_project" "k8s_infra_staging_tools" {
  project_id = "k8s-staging-infra-tools"
}

resource "google_service_account_iam_member" "cloudbuild_deploy_oci_proxy" {
  // NOTE: this is not really sensitive, we just don't need to log it in the shared module ...
  service_account_id = nonsensitive(module.oci-proxy.service_account_id)
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.k8s_infra_staging_tools.number}@cloudbuild.gserviceaccount.com"
}

resource "google_cloud_run_service_iam_member" "gcb_builder_sa" {
  project = local.project_id
  // NOTE: this is not really sensitive, we just don't need to log it in the shared module ...
  for_each = nonsensitive(module.oci-proxy.region_locations)

  service  = nonsensitive(module.oci-proxy.region_locations[each.key].name)
  location = nonsensitive(module.oci-proxy.region_locations[each.key].location)
  role     = "roles/run.developer"
  member   = "serviceAccount:${data.google_project.k8s_infra_staging_tools.number}@cloudbuild.gserviceaccount.com"
}
