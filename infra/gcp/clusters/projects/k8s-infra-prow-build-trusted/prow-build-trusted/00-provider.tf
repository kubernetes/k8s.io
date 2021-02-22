/*
This file defines:
- Required Terraform version
- Required provider versions
- Storage backend details
*/

terraform {
  required_version = "~> 0.13.6"

  backend "gcs" {
    bucket = "k8s-infra-clusters-terraform"
    prefix = "k8s-infra-prow-build-trusted/prow-build-trusted" // $project_name/$cluster_name
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.46.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 3.46.0"
    }
  }
}
