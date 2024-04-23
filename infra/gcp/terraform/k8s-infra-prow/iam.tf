/*
Copyright 2024 The Kubernetes Authors.

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

module "iam" {
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 7"

  projects = [module.project.project_id]

  mode = "authoritative"

  bindings = {
    "roles/artifactregistry.reader" = [
      "serviceAccount:${google_service_account.gke_nodes.email}",
    ]
    "roles/container.admin" = [
      "serviceAccount:${google_service_account.argocd.email}",
    ]

    "roles/logging.logWriter" = [
      "serviceAccount:${google_service_account.gke_nodes.email}",
    ]

    "roles/monitoring.metricWriter" = [
      "serviceAccount:${google_service_account.gke_nodes.email}",
    ]
    // IF GCB needs additional privileges beyond the documented roles please use a custom service account with it
    // https://cloud.google.com/build/docs/cloud-build-service-account
    "roles/cloudbuild.builds.editor" = [
      "serviceAccount:gcb-builder@k8s-infra-prow-build-trusted.iam.gserviceaccount.com",
    ]
    "roles/owner" = [
      "group:k8s-infra-prow-oncall@kubernetes.io",
    ]
  }
}

resource "google_service_account" "gke_nodes" {
  account_id   = "gke-nodes"
  display_name = "GKE Nodes"
  project      = module.project.project_id
}

resource "google_service_account" "argocd" {
  account_id   = "argocd"
  display_name = "ArgoCD"
  project      = module.project.project_id
}
