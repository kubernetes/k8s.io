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

// Ensure k8s-infra-oci-proxy-admins@kubernetes.io has admin access to this project
resource "google_project_iam_member" "k8s_infra_oci_proxy_admins" {
  project = google_project.project.id
  role    = "roles/owner"
  member  = "group:k8s-infra-oci-proxy-admins@kubernetes.io"
}


resource "google_service_account" "oci-proxy" {
  project      = google_project.project.project_id
  account_id   = "oci-proxy-prod"
  display_name = "Minimal Service Account for OCI Proxy"
}

// Make each service invokable by all users.
resource "google_cloud_run_service_iam_member" "allUsers" {
  project  = google_project.project.project_id
  for_each = google_cloud_run_service.oci-proxy

  service  = google_cloud_run_service.oci-proxy[each.key].name
  location = google_cloud_run_service.oci-proxy[each.key].location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_service" "oci-proxy" {
  project  = google_project.project.project_id
  for_each = var.cloud_run_config
  name     = "${var.project_id}-${each.key}"
  location = each.key

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "10" // TODO: adjust to control costs
        "run.googleapis.com/launch-stage"  = "BETA"
      }
    }
    spec {
      service_account_name = google_service_account.oci-proxy.email
      containers {
        image = "us-central1-docker.pkg.dev/k8s-artifacts-prod/images/infra-tools/archeio@${var.digest}"
        args  = ["-v=3"]

        dynamic "env" {
          for_each = each.value.environment_variables
          content {
            name  = env.value["name"]
            value = env.value["value"]
          }
        }

        // ensure this match the value for template.spec.containers.resources.limits
        env {
          name  = "GOMAXPROCS"
          value = "1"
        }

        resources {
          limits = {
            "cpu" = "1000m"
          }
        }
      }

      # we can probably hit 1k QPS/core (cloud run's maximum configurable)
      # but we are leaving in a little overhead, if we actually hit 1k qps in
      # a region we can scale to another 1 core instance
      container_concurrency = 800

      // we only serve cheap redirects, 60s is a rather long request
      timeout_seconds = 60
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
      template[0].metadata[0].annotations["client.knative.dev/sandbox"],
      template[0].metadata[0].annotations["run.googleapis.com/user-image"],
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
    ]
  }
}
