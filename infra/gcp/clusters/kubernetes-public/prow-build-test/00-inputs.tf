/*
This file defines:
- Required Terraform version
- Required provider versions
- Storage backend details
- GCP project configuration
*/

terraform {
  required_version = ">= 0.12.8"

  backend "gcs" {
    bucket = "k8s-infra-clusters-terraform"
    prefix = "kubernetes-public/prow-build-test" // $project_name/$cluster_name
  }

  required_providers {
    google      = "~> 2.14"
    google-beta = "~> 2.14"
  }
}

// This configures the source project where we should install the cluster
data "google_project" "project" {
  project_id = "kubernetes-public"
}
