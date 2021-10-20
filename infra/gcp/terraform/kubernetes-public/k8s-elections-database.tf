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

resource "google_sql_database" "database" {
  name     = var.db_name
  project  = data.google_project.project.project_id
  instance = google_sql_database_instance.db_instance.name
}

resource "google_sql_database_instance" "db_instance" {
  project             = data.google_project.project.project_id
  database_version    = var.db_version
  region              = "us-central1"
  deletion_protection = true

  settings {

    tier                  = var.cloudsql_tier
    disk_size             = var.cloudsql_disk_size_gb
    disk_autoresize_limit = var.disk_autoresize_limit
    disk_type             = var.disk_type
    disk_autoresize       = var.disk_autoresize
    availability_type     = "REGIONAL"

    ip_configuration {
      ipv4_enabled    = false
      private_network = "projects/${data.google_project.project.project_id}/global/networks/default"
    }

    database_flags {
      name  = "autovacuum"
      value = "on"
    }

    database_flags {
      name  = "max_connections"
      value = var.cloudsql_max_connections
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    database_flags {
      name  = "pgaudit.log"
      value = "all"
    }

    backup_configuration {
      enabled    = true
      location   = var.cloudsql_backup_location
      start_time = "02:13" # in UTC
    }

    maintenance_window {
      day          = 5
      hour         = 4 # in UTC
      update_track = "stable"
    }


    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }

  }
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "google_sql_user" "db_user" {
  instance = google_sql_database_instance.db_instance.name
  project  = data.google_project.project.project_id
  name     = var.db_user
  password = random_password.db_password.result
}

resource "google_project_iam_binding" "cloud_sql_access" {
  project = data.google_project.project.project_id
  role    = "roles/cloudsql.editor"
  members = [
    "group:k8s-infra-rbac-elekto@kubernetes.io"
  ]
}

resource "google_compute_global_address" "db_private_ip_address" {
  name          = "k8s-infra-db-election-private-ip"
  project       = data.google_project.project.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "projects/${data.google_project.project.project_id}/global/networks/default"
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network = "projects/${data.google_project.project.project_id}/global/networks/default"
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_global_address.db_private_ip_address.name
  ]
}
