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

# Create certificate for artifacts-k8s-io

resource "google_certificate_manager_dns_authorization" "artifacts-k8s-io" {
  name   = "artifacts-k8s-io"
  domain = "artifacts.k8s.io"
}

resource "google_certificate_manager_certificate" "artifacts-k8s-io" {
  name = "artifacts-k8s-io-20230215"
  managed {
    domains            = ["artifacts.k8s.io"]
    dns_authorizations = [google_certificate_manager_dns_authorization.artifacts-k8s-io.id]
  }

  lifecycle {
    ignore_changes = [
      // A TF bug (?) where it tries recreating the resource
      managed[0].dns_authorizations,
    ]
  }
}

# Create a certificate map to control selection of the certificate
resource "google_certificate_manager_certificate_map" "artifacts-k8s-io" {
  project = google_project.project.project_id
  name    = "artifacts-k8s-io"
}

resource "google_certificate_manager_certificate_map_entry" "artifacts-k8s-io-default" {
  project      = google_project.project.project_id
  name         = "artifacts-k8s-io-default"
  map          = google_certificate_manager_certificate_map.artifacts-k8s-io.name
  certificates = [google_certificate_manager_certificate.artifacts-k8s-io.id]
  matcher      = "PRIMARY"
}
