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

locals {

  image = "gcr.io/k8s-staging-infra-tools/redirectserver:${var.tag}"

  external_ips = {
    sandbox = {
      name = "${var.project_id}-sandbox",
    },
    sandbox-v6 = {
      name = "${var.project_id}-sandbox-v6",
      ipv6 = true
    },
  }
}

data "google_organization" "org" {
  domain = "kubernetes.io"
}

resource "google_project" "project" {
  name            = var.project_id
  project_id      = var.project_id
  org_id          = data.google_organization.org.org_id
  billing_account = "018801-93540E-22A20E"
}


// Enable services needed for the project
resource "google_project_service" "project" {
  project = google_project.project.id

  for_each = toset([
    "compute.googleapis.com",
    "containerregistry.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "oslogin.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com"
  ])

  service = each.key
}

// Ensure k8s-infra-porche-admins@kubernetes.io has admin access to this project
resource "google_project_iam_member" "k8s_infra_porche_admins" {
  project = google_project.project.id
  role    = "roles/owner"
  member  = "group:k8s-infra-porche-admins@kubernetes.io"
}


resource "google_service_account" "porche" {
  project      = google_project.project.project_id
  account_id   = "porche-sandbox"
  display_name = "Minimal Service Account for porche"
}

// Make each service invokable by all users.
resource "google_cloud_run_service_iam_member" "allUsers" {
  project  = google_project.project.project_id
  for_each = google_cloud_run_service.regions

  service  = google_cloud_run_service.regions[each.key].name
  location = google_cloud_run_service.regions[each.key].location
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [google_cloud_run_service.regions]
}

//Ensure gcb-builder can auto-deploy artifacts-sandbox.k8s.io
//TODO: create a dedicated service account for auto-deployment
data "google_project" "k8s_infra_staging_tools" {
  project_id = "k8s-staging-infra-tools"
}

resource "google_service_account_iam_member" "cloudbuild_deploy_porche" {
  service_account_id = google_service_account.porche.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.k8s_infra_staging_tools.number}@cloudbuild.gserviceaccount.com"
}

resource "google_cloud_run_service_iam_member" "gcb_builder_sa" {
  project = google_project.project.project_id
  for_each = google_cloud_run_service.regions

  service  = google_cloud_run_service.regions[each.key].name
  location = google_cloud_run_service.regions[each.key].location
  role = "roles/run.developer"
  member = "serviceAccount:${data.google_project.k8s_infra_staging_tools.number}@cloudbuild.gserviceaccount.com"
}


resource "google_cloud_run_service" "regions" {
  project  = google_project.project.project_id
  for_each = var.cloud_run_config
  name     = "${var.project_id}-${each.key}"
  location = each.key

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "3" // Control costs.
        "run.googleapis.com/launch-stage"  = "BETA"
      }
    }
    spec {
      service_account_name = google_service_account.porche.email
      containers {
        image = local.image
        args = [ "-v=3" ]

        dynamic "env" {
          for_each = each.value.environment_variables
          content {
            name  = env.value["name"]
            value = env.value["value"]
          }
        }
      }

      container_concurrency = 5
      // 30 seconds less than cloud scheduler maximum.
      timeout_seconds = 570
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.project["run.googleapis.com"]
  ]

  lifecycle {
    ignore_changes = [
      // This gets added by the Cloud Run API post deploy and causes diffs, can be ignored...
      template[0].metadata[0].annotations["client.knative.dev/user-image"],
      template[0].metadata[0].annotations["run.googleapis.com/sandbox"],
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
      // Ignore changes done on the container specification
      // since this cloud run service is handled by https://github.com/kubernetes-sigs/porche/blob/main/dev/helpers/deploy-to-cloudrun-staging.sh
      template[0].spec[0].containers[0],
    ]
  }
}
