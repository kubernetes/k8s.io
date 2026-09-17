/*
Copyright 2026 The Kubernetes Authors.

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

// Hosts the Antigravity CLI (agy) usage from prowjobs. See:
// https://github.com/kubernetes-sigs/maintainer-tools/blob/main/images/antigravity/Dockerfile

module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.3"

  name            = "k8s-infra-agentic-ai"
  org_id          = "758905017065"
  billing_account = "018801-93540E-22A20E"

  # Sane project defaults
  disable_services_on_destroy = false
  create_project_sa           = false
  random_project_id           = false
  auto_create_network         = false

  deletion_policy = "DELETE"

  labels = {
    "owner" : "ameukam",
    "project" : "agentic-ai"
  }
}

module "services" {
  source     = "terraform-google-modules/project-factory/google//modules/project_services"
  version    = "~> 18.3"
  project_id = module.project.project_id

  activate_apis = [
    "aiplatform.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com"
  ]

  depends_on = [module.project]
}

resource "time_sleep" "project_services" {
  depends_on = [
    module.services
  ]

  create_duration = "45s"
}
