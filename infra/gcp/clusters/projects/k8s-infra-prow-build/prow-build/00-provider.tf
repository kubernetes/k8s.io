/*
This file defines:
- Required provider versions
- Storage backend details
*/

terraform {

  backend "gcs" {
    bucket = "k8s-infra-tf-prow-clusters"
    prefix = "k8s-infra-prow-build/prow-build" // $project_name/$cluster_name
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
