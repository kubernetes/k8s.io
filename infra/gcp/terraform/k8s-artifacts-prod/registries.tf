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

locals {
  // We want to have a registry in every location except the multi region ones
  // gcloud artifacts locations list --format json | jq '.[] | select(.name!="europe" and .name!="asia" and .name!="us") | .name' | awk '{print $0","}' | --version-sort
  registries = [
    "africa-south1",
    # "asia-east1",
    "asia-east2",
    # "asia-northeast1",
    # "asia-northeast2",
    "asia-northeast3",
    # "asia-south1",
    "asia-south2",
    "asia-southeast1",
    "asia-southeast2",
    # "australia-southeast1",
    "australia-southeast2",
    "europe-central2",
    # "europe-north1",
    "europe-north2",
    # "europe-southwest1",
    # "europe-west1",
    # "europe-west2",
    # "europe-west3",
    # "europe-west4",
    "europe-west6",
    # "europe-west8",
    # "europe-west9",
    # "europe-west10",
    "europe-west12",
    "me-central1",
    # "me-central2", # THIS REGION REQUIRES SUPPORT APPROVAL WHICH I STARTED
    "me-west1",
    "northamerica-northeast1",
    "northamerica-northeast2",
    "northamerica-south1",
    "southamerica-east1",
    # "southamerica-west1",
    # "us-central1",
    # "us-east1",
    # "us-east4",
    # "us-east5",
    # "us-south1",
    # "us-west1",
    # "us-west2",
    "us-west3",
    "us-west4",
  ]

}

module "artifact_registry" {
  for_each = toset(local.registries)
  source   = "GoogleCloudPlatform/artifact-registry/google"
  version  = "~> 0.2"

  project_id    = module.project.project_id
  location      = each.key
  format        = "DOCKER"
  repository_id = "images"
  # docker_config = {
  #   immutable_tags = true // APPLY THIS SOON
  # }
  members = {
    readers = ["allUsers"],
  }
}

# # DELETE THIS AFTER ALL THE REGISTRIES ARE IMPORTED
# import {
#   for_each = toset(local.registries)
#   to       = module.artifact_registry[each.key].google_artifact_registry_repository.repo
#   id       = "k8s-artifacts-prod/${each.key}/images"
# }
