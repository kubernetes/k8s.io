
/*
This file defines:
- Required provider versions
- Storage backend details
*/

terraform {

  backend "gcs" {
    bucket = "k8s-infra-clusters-terraform"
    prefix = "monitoring/state" // $project_name/$cluster_name
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.63.0"
    }
  }
}


