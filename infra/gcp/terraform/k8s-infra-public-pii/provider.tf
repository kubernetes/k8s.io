/*
This file defines:
- Required provider versions
- Storage backend details
*/

terraform {

  backend "gcs" {
    bucket = "k8s-infra-tf-public-pii"
    prefix = "k8s-infra-public"
  }


  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.74.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 3.74.0"
    }
  }
}
