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
  version = "~> 8.0"

  projects = ["kubernetes-public"]

  mode = "authoritative"

  bindings = {
    "roles/secretmanager.secretAccessor" = [
      "serviceAccount:kubernetes-external-secrets@kubernetes-public.iam.gserviceaccount.com",
      "principal://iam.googleapis.com/projects/16065310909/locations/global/workloadIdentityPools/k8s-infra-prow.svc.id.goog/subject/ns/external-secrets/sa/external-secrets",
    ]
    "roles/dns.admin" = [
      "group:k8s-infra-dns-admins@kubernetes.io",
      "principal://iam.googleapis.com/projects/16065310909/locations/global/workloadIdentityPools/k8s-infra-prow.svc.id.goog/subject/ns/cert-manager/sa/cert-manager",
      "serviceAccount:dns-pusher@kubernetes-public.iam.gserviceaccount.com",
      "serviceAccount:k8s-infra-dns-updater@kubernetes-public.iam.gserviceaccount.com"
    ]
    "roles/bigquery.admin" = [
      "serviceAccount:datadog@k8s-infra-seed.iam.gserviceaccount.com"
    ]
  }
}
