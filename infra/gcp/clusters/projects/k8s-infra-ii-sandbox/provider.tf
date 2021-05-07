/*
This file defines:
- Required provider versions
- Storage backend details
*/

terraform {

  backend "gcs" {
    bucket = "k8s-infra-tf-sandbox-ii"
    // TODO(spiffxp): the names not matching weirds me out a bit, it would be
    //                nice to rename the project at some point
    prefix = "k8s-infra-ii-sandbox"
  }


  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.66.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 3.66.0"
    }
  }
}
