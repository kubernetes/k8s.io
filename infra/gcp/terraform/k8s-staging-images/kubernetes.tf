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

// k8s-staging-kubernetes is a special project that holds only kubernetes staging images
module "kubernetes" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 17.1"

  name            = "k8s-staging-kubernetes"
  project_id      = "k8s-staging-kubernetes"
  folder_id       = "713040427754"
  billing_account = "018801-93540E-22A20E"

  # Sane project defaults
  default_service_account     = "keep"
  disable_services_on_destroy = false
  create_project_sa           = false
  random_project_id           = false
  auto_create_network         = true


  activate_apis = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com"
  ]
}

module "kubernetes_ar" {
  source  = "GoogleCloudPlatform/artifact-registry/google"
  version = "~> 0.2"

  project_id    = module.kubernetes.project_id
  location      = "us"
  format        = "DOCKER"
  repository_id = "gcr.io"
  members = {
    readers = ["allUsers"],
    writers = [
      "serviceAccount:648026197307@cloudbuild.gserviceaccount.com", // Delete this once we move away from google.com projects
      "serviceAccount:304687256732@cloudbuild.gserviceaccount.com",
    ],
  }
  cleanup_policy_dry_run = false
  cleanup_policies = {
    "delete-images-older-than-90-days" = {
      action = "DELETE"
      condition = {
        older_than = "7776000s" # 90d
      }
    }
  }
}


module "kubernetes_iam" {
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 8"

  projects = [module.kubernetes.project_id]

  mode = "authoritative"

  bindings = {
    "roles/cloudbuild.builds.editor" = [
      "serviceAccount:gcb-builder@k8s-infra-prow-build-trusted.iam.gserviceaccount.com",
      "serviceAccount:615281671549@cloudbuild.gserviceaccount.com"
    ]
    "roles/owner" = [
      "group:k8s-infra-release-admins@kubernetes.io",
    ]
    "roles/viewer" = [
      "group:k8s-infra-release-editors@kubernetes.io",
      "group:k8s-infra-release-viewers@kubernetes.io"
    ]
  }
}
