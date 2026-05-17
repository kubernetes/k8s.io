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

module "iam" {
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 8"

  projects = ["k8s-infra-oci-proxy"]

  mode = "authoritative"

  bindings = {
    "roles/storage.objectAdmin" = [
      "principal://iam.googleapis.com/projects/180382678033/locations/global/workloadIdentityPools/k8s-infra-prow-build-trusted.svc.id.goog/subject/ns/test-pods/sa/infra-tools"
    ],
    "roles/run.admin" = [
      "principal://iam.googleapis.com/projects/180382678033/locations/global/workloadIdentityPools/k8s-infra-prow-build-trusted.svc.id.goog/subject/ns/test-pods/sa/infra-tools"
    ],
    "roles/viewer" = [
      "principal://iam.googleapis.com/projects/180382678033/locations/global/workloadIdentityPools/k8s-infra-prow-build-trusted.svc.id.goog/subject/ns/test-pods/sa/infra-tools"
    ]
  }
}
