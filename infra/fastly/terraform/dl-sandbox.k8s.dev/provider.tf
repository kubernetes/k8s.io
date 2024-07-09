/*
Copyright 2023 The Kubernetes Authors.

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
  backend "gcs" {
    bucket = "k8s-infra-tf-fastly"
    prefix = "cdn.dl-sandbox.k8s.dev"
  }

  required_providers {
    fastly = {
      source  = "fastly/fastly"
      version = "~> 5.11.0"
    }
  }
}

# Configure the Fastly Provider
provider "fastly" {}
