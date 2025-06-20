/*
Copyright 2025 The Kubernetes Authors.

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
- Required provider versions
- Storage backend details
*/

terraform {
  required_version = "1.10.5"

  backend "gcs" {
    bucket = "k8s-infra-tf-gcp-gcve"
    prefix = "k8s-infra-gcp-gcve-vcenter-gateway"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.34.1"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.34.1"
    }
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.13.0"
    }
  }
}

# Setup credentials to vSphere.
provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
}
