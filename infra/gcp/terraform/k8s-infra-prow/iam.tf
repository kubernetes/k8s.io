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
      "principal://iam.googleapis.com/projects/16065310909/locations/global/workloadIdentityPools/k8s-infra-prow.svc.id.goog/subject/ns/argocd/sa/argocd-application-controller",
      "principal://iam.googleapis.com/projects/16065310909/locations/global/workloadIdentityPools/k8s-infra-prow.svc.id.goog/subject/ns/argocd/sa/argocd-applicationset-controller",
      "principal://iam.googleapis.com/projects/16065310909/locations/global/workloadIdentityPools/k8s-infra-prow.svc.id.goog/subject/ns/argocd/sa/argocd-server",
    ]

    "roles/logging.logWriter" = [
      "serviceAccount:${google_service_account.gke_nodes.email}",
      "serviceAccount:${google_service_account.image_builder.email}",
    ]

    "roles/secretmanager.secretAccessor" = [
      "principal://iam.googleapis.com/projects/16065310909/locations/global/workloadIdentityPools/k8s-infra-prow.svc.id.goog/subject/ns/external-secrets/sa/external-secrets",
    ]

    // DEPRIVILIGE THE DEFAULT CLOUD BUILD SERVICE ACCOUNT SO IT CAN'T DO ANYTHING
    "roles/cloudbuild.builds.builder" = []

    "roles/monitoring.metricWriter" = [
      "serviceAccount:${google_service_account.gke_nodes.email}",
    ]
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

resource "google_service_account_iam_binding" "argocd" {
  service_account_id = google_service_account.argocd.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:k8s-infra-prow.svc.id.goog[prow/config-bootstrapper]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[prow/crier]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[prow/deck]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[prow/hook]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[prow/prow-controller-manager]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[prow/sinker]",
  ]
}


resource "google_service_account" "image_builder" {
  account_id   = "image-builder"
  display_name = "Image Builder"
  project      = module.project.project_id
}

resource "google_service_account_iam_member" "image_builder" {
  service_account_id = google_service_account.image_builder.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:gcb-builder@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"
}

resource "google_service_account" "prow" {
  account_id   = "prow-control-plane"
  display_name = "Prow Control Plane"
  project      = module.project.project_id
}

resource "google_service_account_iam_binding" "prow" {
  service_account_id = google_service_account.prow.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:k8s-infra-prow.svc.id.goog[argocd/argocd-application-controller]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[argocd/argocd-server]",
  ]
}

resource "google_service_account" "halogen" {
  account_id   = "halogen"
  display_name = "halogen"
  project      = module.project.project_id
}

resource "google_service_account_iam_binding" "halogen" {
  service_account_id = google_service_account.halogen.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:k8s-infra-prow.svc.id.goog[prow/halogen]",
  ]
}
