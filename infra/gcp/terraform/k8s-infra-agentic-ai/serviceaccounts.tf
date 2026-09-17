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

// Service account assumed by prowjobs running the antigravity image in the
// test-pods namespace of the k8s-infra-prow-build cluster, via Workload
// Identity. The matching KSA lives in
// kubernetes/gke-prow-build/prow/build-serviceaccounts.yaml.
module "agy_agent_service_account" {
  source             = "../modules/workload-identity-service-account"
  project_id         = module.project.project_id
  name               = "agy-agent"
  description        = "used by prowjobs to call Vertex AI with the Antigravity CLI"
  cluster_project_id = "k8s-infra-prow-build"
  cluster_namespace  = "test-pods"
  project_roles = [
    "roles/aiplatform.user",
    "roles/serviceusage.serviceUsageConsumer"
  ]

  depends_on = [time_sleep.project_services]
}
