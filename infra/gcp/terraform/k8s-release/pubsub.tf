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

// Cloud Build publishes the status of the builds of the project to the
// cloud-builds topic once it exists. The level 3 signing build in
// k8s-releng-prod starts on the successful stage builds.
resource "google_pubsub_topic" "cloud_builds" {
  project = module.project.project_id
  name    = "cloud-builds"
}
