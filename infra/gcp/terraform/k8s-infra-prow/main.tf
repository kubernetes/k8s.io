/*
Copyright 2020 The Kubernetes Authors.

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

module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 14.5"

  name            = "k8s-infra-prow"
  project_id      = "k8s-infra-prow"
  folder_id       = "411137699919" # manually created, will create via TF once I start working on the org
  org_id          = "758905017065"
  billing_account = "018801-93540E-22A20E"

  # Sane project defaults
  default_service_account     = "keep"
  disable_services_on_destroy = false
  create_project_sa           = false
  random_project_id           = false
  auto_create_network         = true


  activate_apis = [
    "secretmanager.googleapis.com",
    "cloudasset.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudkms.googleapis.com",
    "certificatemanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com"
  ]
}
