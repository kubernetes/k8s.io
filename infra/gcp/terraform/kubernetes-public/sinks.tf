/*
Copyright 2023 The Kubernetes Authors.

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

resource "google_logging_project_sink" "legacy_pkg_logs" {
  project     = data.google_project.project.project_id
  name        = "legacy-pkgs-k8s-io-logs-sink"
  destination = "bigquery.googleapis.com/projects/k8s-infra-public-pii/datasets/legacy_pkgs_k8s_io_logs"

  bigquery_options {
    use_partitioned_tables = false
  }

  unique_writer_identity = true

  filter = "logName=\"projects/kubernetes-public/logs/stdout\" AND (labels.k8s-pod/app=\"k8s-io-packages\" OR labels.k8s-pod/app=\"k8s-io\") AND (httpRequest.requestUrl=~\"yum|apt\")"
}
