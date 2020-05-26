/*
This file defines:
- Required Terraform version
- Required provider versions
- Storage backend details
*/

terraform {
  required_version = "~> 0.12.20"

  backend "gcs" {
    bucket = "k8s-infra-clusters-terraform"
    prefix = "k8s-infra-prow-build-trusted/prow-build-trusted" // $project_name/$cluster_name
  }

  required_providers {
    google      = "~> 3.19.0"
    google-beta = "~> 3.19.0"
  }
}
