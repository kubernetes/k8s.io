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


module "log_export" {
  source  = "terraform-google-modules/log-export/google"
  version = "~> 11.1"

  destination_uri      = module.destination.destination_uri
  filter               = "jsonPayload.message = image_pull"
  log_sink_name        = "analytics"
  parent_resource_id   = var.project_id
  parent_resource_type = "project"
  bigquery_options = {
    use_partitioned_tables = false
  }
}

module "destination" {
  source  = "terraform-google-modules/log-export/google//modules/bigquery"
  version = "~> 11.1"

  project_id               = var.project_id
  dataset_name             = "analytics"
  log_sink_writer_identity = module.log_export.writer_identity
}
