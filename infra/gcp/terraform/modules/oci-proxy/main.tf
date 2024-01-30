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
  cloud_run_config = {
    asia-east1 = {
      // GCP asia-east1 is Changhua County, Taiwan
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS Cloudfront
          value = "https://d39mqg4b1dx9z1.cloudfront.net",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://asia-east1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP asia-northeast1 is Tokyo, Japan
    asia-northeast1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS ap-northeast-1 is Tokyo
          value = "https://prod-registry-k8s-io-ap-northeast-1.s3.dualstack.ap-northeast-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://asia-northeast1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP asia-northeast2 is Osaka, Japan
    asia-northeast2 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS ap-northeast-1 is Tokyo
          value = "https://prod-registry-k8s-io-ap-northeast-1.s3.dualstack.ap-northeast-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://asia-northeast2-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP asia-south1 is Mumbai, India
    asia-south1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS ap-south-1 is Mumbai
          value = "https://prod-registry-k8s-io-ap-south-1.s3.dualstack.ap-south-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://asia-south1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP australia-southeast1 is Sydney
    australia-southeast1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS ap-southeast-1 is Singapore
          value = "https://prod-registry-k8s-io-ap-southeast-1.s3.dualstack.ap-southeast-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://australia-southeast1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP europe-north1 is Hamina, Finland
    europe-north1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS eu-central-1 is Frankfurt
          value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://europe-north1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP europe-southwest1 is Madrid, Spain
    europe-southwest1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS eu-central-1 is Frankfurt
          value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://europe-southwest1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP europe-west1 is St. Ghislain, Belgium
    europe-west1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS Cloudfront
          value = "https://d39mqg4b1dx9z1.cloudfront.net",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://europe-west1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP europe-west10 is Berlin, Germany
    europe-west10 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS eu-central-1 is Frankfurt
          value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://europe-west10-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP europe-west2 is London, UK
    europe-west2 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS eu-west-1 is Ireland
          value = "https://prod-registry-k8s-io-eu-west-1.s3.dualstack.eu-west-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://europe-west2-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP europe-west3 is Frankfurt, Germany
    europe-west3 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS eu-central-1 is Frankfurt
          value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://europe-west3-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP europe-west4 is Eemshaven, Netherlands
    europe-west4 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS Cloudfront
          value = "https://d39mqg4b1dx9z1.cloudfront.net",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://europe-west4-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP europe-west8 is Milan, Italy
    europe-west8 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS eu-central-1 is Frankfurt
          value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://europe-west8-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP europe-west9 is Paris, France
    europe-west9 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS eu-west-1 is in Ireland
          value = "https://prod-registry-k8s-io-eu-west-1.s3.dualstack.eu-west-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://europe-west9-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP southamerica-west1 is Santiago, Chile
    southamerica-west1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS us-east-1 is Virginia, USA
          // See: https://github.com/kubernetes/k8s.io/pull/4739/files#r1100667255
          value = "https://prod-registry-k8s-io-us-east-1.s3.dualstack.us-east-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://southamerica-west1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP us-central1 is Iowa, USA
    us-central1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS us-east-2 is Ohio, USA
          value = "https://prod-registry-k8s-io-us-east-2.s3.dualstack.us-east-2.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://us-central1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP us-east1 is South Carolina, USA
    us-east1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS us-east-1 is Virginia, USA
          value = "https://prod-registry-k8s-io-us-east-1.s3.dualstack.us-east-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://us-east1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP us-east4 is Virginia, USA
    us-east4 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS us-east-1 is Virginia, USA
          value = "https://prod-registry-k8s-io-us-east-1.s3.dualstack.us-east-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://us-east4-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP us-east5 is Ohio, USA
    us-east5 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS us-east-2 is Ohio, USA
          value = "https://prod-registry-k8s-io-us-east-2.s3.dualstack.us-east-2.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://us-east5-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP us-south1 is Texas, USA
    us-south1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS us-east-2 is Ohio, USA
          value = "https://prod-registry-k8s-io-us-east-2.s3.dualstack.us-east-2.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://us-south1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP us-west1 is Oregon, USA
    us-west1 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS us-west-2 is Oregon, USA
          value = "https://prod-registry-k8s-io-us-west-2.s3.dualstack.us-west-2.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://us-west1-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
    // GCP us-west2 is California, USA
    us-west2 = {
      environment_variables = [
        {
          name = "DEFAULT_AWS_BASE_URL",
          // AWS us-west-1 is California, USA
          value = "https://prod-registry-k8s-io-us-west-1.s3.dualstack.us-west-1.amazonaws.com",
        },
        {
          name  = "UPSTREAM_REGISTRY_ENDPOINT",
          value = "https://us-west2-docker.pkg.dev"
        },
        {
          name  = "UPSTREAM_REGISTRY_PATH",
          value = "k8s-artifacts-prod/images"
        }
      ]
    }
  }
}


// Enable services needed for the project
resource "google_project_service" "project" {
  project = var.project_id

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
  project = var.project_id
  role    = "roles/owner"
  member  = "group:k8s-infra-oci-proxy-admins@kubernetes.io"
}


resource "google_service_account" "oci-proxy" {
  project      = var.project_id
  account_id   = var.service_account_name
  display_name = "Minimal Service Account for OCI Proxy"
}

// Make each service invokable by all users.
resource "google_cloud_run_service_iam_member" "allUsers" {
  project  = var.project_id
  for_each = google_cloud_run_service.oci-proxy

  service  = google_cloud_run_service.oci-proxy[each.key].name
  location = google_cloud_run_service.oci-proxy[each.key].location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_service" "oci-proxy" {
  project  = var.project_id
  for_each = local.cloud_run_config
  name     = "${var.project_id}-${each.key}"
  location = each.key

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "10" // TODO: adjust to control costs
        "run.googleapis.com/launch-stage"  = "BETA"
      }
      labels = {
        "run.googleapis.com/startupProbeType" = "Default"
      }
    }
    spec {
      service_account_name = google_service_account.oci-proxy.email
      containers {
        // NOTE: We deploy from staging because:
        // - We pin by digest anyhow (so it's comparably secure)
        // - We need to be able to deploy registry fixes ASAP
        // - We will eventually auto-deploy staging by overriding the project and digest on the production config to avoid skew
        // If you're interested in running this image yourself releases are available at registry.k8s.io/infra-tools/archeio
        image = "gcr.io/k8s-staging-infra-tools/archeio@${var.digest}"
        args  = ["-v=${var.verbosity}"]

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
            // default, also the minimum permitted for second generation
            // https://cloud.google.com/run/docs/about-execution-environments
            "memory" = "512Mi"
          }
        }

        startup_probe {
          failure_threshold     = 1
          initial_delay_seconds = 0
          period_seconds        = 240
          timeout_seconds       = 240
          tcp_socket {
            port = 8080
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
