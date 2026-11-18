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
  principals = {
    k8s-infra-gcr-promoter = {
      # description = null
      display_name = "k8s-infra container image promoter"
      users = [
        "principal://iam.googleapis.com/projects/180382678033/locations/global/workloadIdentityPools/k8s-infra-prow-build-trusted.svc.id.goog/subject/ns/test-pods/sa/k8s-infra-gcr-promoter",
        "principal://iam.googleapis.com/projects/180382678033/locations/global/workloadIdentityPools/k8s-infra-prow-build-trusted.svc.id.goog/subject/ns/test-pods/sa/s3-sync"
      ]
    },
    k8s-infra-image-promotion = {
      display_name = "k8s-infra image promotion"
      users = [
        "principal://iam.googleapis.com/projects/180382678033/locations/global/workloadIdentityPools/k8s-infra-prow-build-trusted.svc.id.goog/subject/ns/test-pods/sa/k8s-infra-image-promotion"
      ]
    }
  }
}

resource "google_service_account" "build_sa" {
  for_each     = local.principals
  display_name = each.value.display_name
  account_id   = each.key
  project      = module.project.project_id
}

resource "google_service_account_iam_binding" "build_sa" {
  for_each           = local.principals
  service_account_id = google_service_account.build_sa[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  members            = each.value.users
}


# projects/k8s-artifacts-prod/serviceAccounts/k8s-infra-image-promotion@k8s-artifacts-prod.iam.gserviceaccount.com
