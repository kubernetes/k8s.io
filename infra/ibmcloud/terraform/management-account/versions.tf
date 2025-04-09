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

terraform {
  backend "s3" {
    bucket                      = "k8s-infra-tf-states"
    key                         = "management-account/terraform.tfstate"
    region                      = "us-geo"
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_credentials_validation = true
    skip_s3_checksum            = true
    endpoints = {
      s3 = "https://s3.us.cloud-object-storage.appdomain.cloud"
    }
    secret_key = "<YOUR_SECRET_KEY>"
    access_key = "<YOUR_ACCESS_KEY>"
  }
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}
