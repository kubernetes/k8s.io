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
      "serviceAccount:${google_service_account.prow.email}",
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
    "serviceAccount:k8s-infra-prow.svc.id.goog[argocd/argocd-application-controller]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[argocd/argocd-server]",
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
    "serviceAccount:k8s-infra-prow.svc.id.goog[default/config-bootstrapper]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[default/crier]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[default/deck]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[default/hook]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[default/prow-controller-manager]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[default/sinker]",
    "serviceAccount:k8s-infra-prow.svc.id.goog[default/tide]",
  ]
}

// Unique service account for GCS notification PubSub topics.
// Used to publish GCS updates to PubSub.
data "google_storage_project_service_account" "gcs_account" {
  project = module.project.project_id
}

// Bind storage SA to publish to PubSub.
resource "google_pubsub_topic_iam_binding" "publish_binding" {
  topic   = google_pubsub_topic.kubernetes_ci_logs_topic.name
  project = module.project.project_id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

// Also bind TestGrid and Kettle as subscribers of this topic.
resource "google_pubsub_topic_iam_binding" "read_binding" {
  topic   = google_pubsub_topic.kubernetes_ci_logs_topic.name
  project = module.project.project_id
  role    = "roles/pubsub.subscriber"
  members = [
    "serviceAccount:testgrid-canary@k8s-testgrid.iam.gserviceaccount.com",
    "serviceAccount:updater@k8s-testgrid.iam.gserviceaccount.com",
    "serviceAccount:kettle@kubernetes-public.iam.gserviceaccount.com",
  ]
}

# https://cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes#kubernetes
# This is a community owned K8s Cluster inside IBM Cloud, have a look at the infra/ibm/terraform folder for more details
resource "google_iam_workload_identity_pool" "ibm_clusters" {
  project                   = module.project.project_id
  workload_identity_pool_id = "ibm-clusters"
}

data "http" "ppc64le_issuer" {
  url      = "https://73725434-jp-osa.lb.appdomain.cloud:6443/.well-known/openid-configuration"
  insecure = true
}

data "http" "ppc64le_jwks" {
  url      = "https://73725434-jp-osa.lb.appdomain.cloud:6443/openid/v1/jwks"
  insecure = true
}

resource "google_iam_workload_identity_pool_provider" "ppc64le" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.ibm_clusters.workload_identity_pool_id
  project                            = module.project.project_id
  workload_identity_pool_provider_id = "ppc64le"

  attribute_mapping = {
    "google.subject"                 = "\"ns/\" + assertion['kubernetes.io']['namespace'] + \"/sa/\" + assertion['kubernetes.io']['serviceaccount']['name']"
    "attribute.namespace"            = "assertion['kubernetes.io']['namespace']"
    "attribute.service_account_name" = "assertion['kubernetes.io']['serviceaccount']['name']"
    "attribute.pod"                  = "assertion['kubernetes.io']['pod']['name']"
  }
  oidc {
    allowed_audiences = ["sts.googleapis.com"]
    issuer_uri        = jsondecode(data.http.ppc64le_issuer.response_body)["issuer"]
    jwks_json         = data.http.ppc64le_jwks.response_body
  }
}

data "http" "s390x_issuer" {
  url      = "https://d7b2a019-eu-de.lb.appdomain.cloud:6443/.well-known/openid-configuration"
  insecure = true
}

data "http" "s390x_jwks" {
  url      = "https://d7b2a019-eu-de.lb.appdomain.cloud:6443/openid/v1/jwks"
  insecure = true
}

resource "google_iam_workload_identity_pool_provider" "s390x" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.ibm_clusters.workload_identity_pool_id
  project                            = module.project.project_id
  workload_identity_pool_provider_id = "s390x"

  attribute_mapping = {
    "google.subject"                 = "\"ns/\" + assertion['kubernetes.io']['namespace'] + \"/sa/\" + assertion['kubernetes.io']['serviceaccount']['name']"
    "attribute.namespace"            = "assertion['kubernetes.io']['namespace']"
    "attribute.service_account_name" = "assertion['kubernetes.io']['serviceaccount']['name']"
    "attribute.pod"                  = "assertion['kubernetes.io']['pod']['name']"
  }
  oidc {
    allowed_audiences = ["sts.googleapis.com"]
    issuer_uri        = jsondecode(data.http.s390x_issuer.response_body)["issuer"]
    jwks_json         = data.http.s390x_jwks.response_body
  }
}
