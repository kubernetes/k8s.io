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
  version = "~> 8.0"

  name       = "k8s-staging-images-gcb"
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
      role   = "roles/storage.admin"
      member = "serviceAccount:gcb-builder@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"
    }
  ]
}
