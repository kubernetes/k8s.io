/*
This file defines:
- Required Terraform version
- Required provider versions
- Storage backend details
- Input variables
*/

terraform {
  required_version = ">= 0.12.6"

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "k8s-infra"

    workspaces {
      // should match the name of the gcp project
      name = "k8s-infra-dev-cluster-turnup"
    }
  }

  required_providers {
    google      = "~> 2.13"
    google-beta = "~> 2.13"
  }
}

variable "cluster_name" {
  type        = string
  description = <<EOT
Name of the GKE cluster to create
EOT
}

variable "project" {
  type        = string
  description = <<EOT
The name of the GCP project to create the cluster in
EOT
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = <<EOT
GCP region to create resources in
See https://cloud.google.com/compute/docs/regions-zones/ for valid values
EOT
}
