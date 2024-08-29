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

module "gcb_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 5"

  name       = "k8s-infra-prow-gcb"
  project_id = module.project.project_id
  location   = "us"

  lifecycle_rules = [{
    action = {
      type = "Delete"
    }
    condition = {
      age        = 7
      with_state = "ANY"
    }
  }]

  iam_members = [
    {
      role   = "roles/storage.admin"
      member = "serviceAccount:${google_service_account.image_builder.email}"
    },
    {
      role   = "roles/storage.admin"
      member = "serviceAccount:gcb-builder@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"
    }
  ]
}

// Create gs://k8s-testgrid-config to store K8s TestGrid config.
module "testgrid_config_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 5"

  name       = "k8s-testgrid-config"
  project_id = module.project.project_id
  location   = "us"

  lifecycle_rules = [{
    action = {
      type = "Delete"
    }
    condition = {
      age        = 90 # 90d
      with_state = "ANY"
    }
  }]

  iam_members = [
    {
      // Let the upload job write to this bucket.
      role   = "roles/storage.objectAdmin"
      member = "serviceAccount:k8s-testgrid-config-updater@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"
    },
    {
      // Let K8s TestGrid canary read configs from this bucket. 
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:testgrid-canary@k8s-testgrid.iam.gserviceaccount.com"
    },
    {
      // Let K8s TestGrid production read configs from this bucket.
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:updater@k8s-testgrid.iam.gserviceaccount.com"
    }
  ]
}

// Create gs://k8s-testgrid-config to store K8s TestGrid config.
module "prow_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 5"

  name       = "kubernetes-ci-logs"
  project_id = module.project.project_id
  location   = "us-central1"

  # TODO: BenTheElder, what lifecycle policy do we have on the previous bucket
  # lifecycle_rules = [{
  #   action = {
  #     type = "Delete"
  #   }
  #   condition = {
  #     age        = 90 # 90d
  #     with_state = "ANY"
  #   }
  # }]

  iam_members = [
    {
      // prow pod-utils service account
      role   = "roles/storage.objectAdmin"
      member = "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com"
    },
    {
      role   = "roles/storage.objectAdmin"
      member = "serviceAccount:${google_service_account.prow.email}"
    },
    {
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    },
  ]
}

