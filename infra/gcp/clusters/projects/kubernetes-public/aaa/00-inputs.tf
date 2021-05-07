/*
This file defines:
- Required Terraform version
- Required provider versions
- Storage backend details
- GCP project configuration
*/

terraform {
  required_version = "~> 0.13.0"

  backend "gcs" {
    bucket = "k8s-infra-tf-public-clusters"
    prefix = "kubernetes-public/aaa" // $project_name/$cluster_name
  }

  required_providers {
    google = {
      version = "~> 3.66.0"
    }
    google-beta = {
      version = "~> 3.66.0"
    }
  }
}

// This configures the source project where we should install the cluster
data "google_project" "project" {
  project_id = "kubernetes-public"
}
