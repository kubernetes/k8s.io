/*
This file defines:
- Required Terraform version
- Required provider versions
- Storage backend details
*/

terraform {
  required_version = ">= 0.12.8"

  backend "gcs" {
    bucket = "k8s-infra-clusters-terraform"
    prefix = "kubernetes-public/prow-build-test" // $project_name/$cluster_name
  }

  required_providers {
    google      = "~> 3.19.0"
    google-beta = "~> 3.19.0"
  }
}
