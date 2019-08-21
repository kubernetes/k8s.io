/*
This file defines the data sources for the GCP project
*/

data "google_project" "project" {
  project_id = var.project
}

data "google_container_engine_versions" "us-central1" {
  project        = data.google_project.project.id
  location       = var.region
  version_prefix = "1.13."
}
