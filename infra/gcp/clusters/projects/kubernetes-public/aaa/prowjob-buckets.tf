/**
 * Copyright 2020 The Kubernetes Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
This file defines all GCS buckets that prow jobs write to
*/

locals {
  scalability_tests_logs_bucket_name    = "k8s-infra-scalability-tests-logs" // Name of the bucket for the scalability test results
  scalability_golang_builds_bucket_name = "k8s-infra-scale-golang-builds"    // Name of the bucket for the scalability golang builds
}

// Bucket for scalability tests results
resource "google_storage_bucket" "scalability_tests_logs" {
  project = data.google_project.project.project_id
  name    = local.scalability_tests_logs_bucket_name

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 90 // days
    }
    action {
      type = "Delete"
    }
  }
}

data "google_iam_policy" "scalability_tests_logs_bindings" {
  // Ensure k8s-infra-prow-oncall has admin privileges, and keep existing
  // legacy bindings since we're overwriting all existing bindings below
  binding {
    members = [
      "group:k8s-infra-prow-oncall@kubernetes.io",
    ]
    role = "roles/storage.admin"
  }
  binding {
    members = [
      "group:k8s-infra-prow-oncall@kubernetes.io",
      "projectEditor:${data.google_project.project.project_id}",
      "projectOwner:${data.google_project.project.project_id}",
    ]
    role = "roles/storage.legacyBucketOwner"
  }
  binding {
    members = [
      "projectViewer:${data.google_project.project.project_id}",
    ]
    role = "roles/storage.legacyBucketReader"
  }
  // Ensure prow-build serviceaccount can write to bucket
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com",
    ]
  }
  // Ensure bucket is world readable
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "allUsers"
    ]
  }
}

// Authoritative iam-policy: replaces any existing policy attached to the bucket
resource "google_storage_bucket_iam_policy" "scalability_tests_logs_policy" {
  bucket      = google_storage_bucket.scalability_tests_logs.name
  policy_data = data.google_iam_policy.scalability_tests_logs_bindings.policy_data
}

// Bucket used for Golang Scalability builds
resource "google_storage_bucket" "scalability_golang_builds" {
  project = data.google_project.project.project_id
  name    = local.scalability_golang_builds_bucket_name

  uniform_bucket_level_access = true
}

data "google_iam_policy" "scalability_golang_builds_bindings" {
  // Ensure k8s-infra-sig-scalability-oncall has admin privileges
  binding {
    members = [
      "group:k8s-infra-sig-scalability-oncall@kubernetes.io",
    ]
    role = "roles/storage.admin"
  }
  // Maintain legacy admins privilegies
  binding {
    members = [
      "group:k8s-infra-sig-scalability-oncall@kubernetes.io",
      "projectEditor:${data.google_project.project.project_id}",
      "projectOwner:${data.google_project.project.project_id}",
    ]
    role = "roles/storage.legacyBucketOwner"
  }
  binding {
    members = [
      "projectViewer:${data.google_project.project.project_id}",
    ]
    role = "roles/storage.legacyBucketReader"
  }
  // Ensure prow-build serviceaccount can write to bucket
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com",
    ]
  }
  // Ensure bucket is world readable
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "allUsers"
    ]
  }
}

// Authoritative iam-policy: replaces any existing policy attached to the bucket
resource "google_storage_bucket_iam_policy" "scalability_golang_builds_policy" {
  bucket      = google_storage_bucket.scalability_golang_builds.name
  policy_data = data.google_iam_policy.scalability_golang_builds_bindings.policy_data
}
