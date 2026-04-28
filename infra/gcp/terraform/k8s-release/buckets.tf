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

module "gcb_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 8.0"

  name       = "k8s-release-gcb"
  project_id = module.project.project_id
  versioning = false
  location   = "us"

  lifecycle_rules = [{
    action = {
      type = "Delete"
    }
    condition = {
      age        = 60 # 60d
      with_state = "ANY"
    }
  }]
}

module "mock_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 8.0"

  name       = "5d7373bbdcb8270361b96548387bf2a9ad0d48758c35"
  project_id = module.project.project_id
  location   = "us"

  lifecycle_rules = [{
    action = {
      type = "Delete"
    }
    condition = {
      age        = 60 # 60d
      with_state = "ANY"
    }
  }]
  iam_members = [
    {
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }
  ]
}


module "release_dev" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 8.0"

  name              = "k8s-release-dev"
  project_id        = module.project.project_id
  location          = "us"
  versioning        = false
  log_bucket        = "k8s-infra-artifacts-gcslogs"
  log_object_prefix = "k8s-release-dev"

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
      role   = "roles/storage.legacyBucketWriter"
      member = "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com"
    },
    {
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }
  ]
}


module "release" {
  // WE NEED TO DELETE THIS BUCKET, it exists as with a hashed name in k8s-infra-releases-prod and served via Fastly
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 8.0"

  name       = "k8s-release"
  project_id = module.project.project_id
  versioning = false
  location   = "us"
  iam_members = [
    {
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }
  ]
}


