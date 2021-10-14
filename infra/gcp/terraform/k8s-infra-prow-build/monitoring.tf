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

/*
This file defines:
- Monitoring resources for k8s-infra-prow-build
*/

resource "google_monitoring_dashboard" "dashboards" {
  for_each       = fileset("${path.module}/dashboards", "*.json")
  dashboard_json = file("${path.module}/dashboards/${each.value}")
  project        = module.project.project_id
}
