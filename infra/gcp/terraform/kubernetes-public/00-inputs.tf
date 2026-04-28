/*
Copyright 2021 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/*
This file defines:
- Required Terraform version
- Required provider versions
- Storage backend details
- GCP project configuration
*/

locals {
  prow_owners = "k8s-infra-prow-oncall@kubernetes.io"
}

terraform {
  required_version = "~> 1.10.5"

  backend "gcs" {
    bucket = "k8s-infra-tf-public-clusters"
    prefix = "kubernetes-public/aaa" // $project_name/$cluster_name
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.31.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.31.0"
    }
  }
}

// This configures the source project where we should install the cluster
data "google_project" "project" {
  project_id = "kubernetes-public"
}
