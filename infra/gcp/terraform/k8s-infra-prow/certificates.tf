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

resource "google_certificate_manager_dns_authorization" "prow" {
  name        = "dns-authz-prow-k8s-io"
  description = "*.prow.k8s.io challenge"
  domain      = "prow.k8s.io"
  project     = module.project.project_id
}

resource "google_certificate_manager_certificate" "prow" {
  name        = "prow-certificates"
  description = "Prow Certificates"
  project     = module.project.project_id
  managed {
    domains = ["prow.k8s.io", "*.prow.k8s.io"]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.prow.id
    ]
  }
}

resource "google_certificate_manager_certificate_map" "prow" {
  project = module.project.project_id
  name    = "prow-certificates"
}
resource "google_certificate_manager_certificate_map_entry" "prow" {
  project      = module.project.project_id
  name         = "prow-certificates"
  map          = google_certificate_manager_certificate_map.prow.name
  certificates = [google_certificate_manager_certificate.prow.id]
  matcher      = "PRIMARY"
}
