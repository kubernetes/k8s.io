/*
Copyright 2021 The Kubernetes Authors.

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

resource "google_compute_address" "boskos_metrics" {
  name         = "boskos-metrics"
  description  = "to allow monitoring.k8s.prow.io to scrape boskos metrics"
  project      = module.project.project_id
  region       = local.cluster_location
  address_type = "EXTERNAL"
}

resource "google_compute_address" "kubernetes_external_secrets_metrics" {
  name         = "kubernetes-external-secrets-metrics"
  description  = "to allow monitoring.k8s.prow.io to scrape kubernetes-external-secrets metrics"
  project      = module.project.project_id
  region       = local.cluster_location
  address_type = "EXTERNAL"
}

resource "google_compute_global_address" "grafana_ingress" {
  name         = "grafana-ingress"
  description  = "to expose grafana running in-cluster on monitoring-gke.prow.k8s.io"
  project      = module.project.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}
