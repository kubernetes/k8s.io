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

locals {
  key    = var.ibmcloud_api_key
  region = "us-south"
  zone   = "us-south"
}

provider "ibm" {
  ibmcloud_api_key = local.key
  region           = local.region
  zone             = local.zone
}

provider "ibm" {
  alias            = "powervs_sao01"
  ibmcloud_api_key = local.key
  region           = "sao"
  zone             = "sao01"
}

provider "ibm" {
  alias            = "powervs_lon04"
  ibmcloud_api_key = local.key
  region           = "lon"
  zone             = "lon04"
}

provider "ibm" {
  alias            = "powervs_lon06"
  ibmcloud_api_key = local.key
  region           = "lon"
  zone             = "lon06"
}

provider "ibm" {
  alias            = "powervs_syd04"
  ibmcloud_api_key = local.key
  region           = "syd"
  zone             = "syd04"
}

provider "ibm" {
  alias            = "powervs_syd05"
  ibmcloud_api_key = local.key
  region           = "syd"
  zone             = "syd05"
}

provider "ibm" {
  alias            = "powervs_tok04"
  ibmcloud_api_key = local.key
  region           = "tok"
  zone             = "tok04"
}

provider "ibm" {
  alias            = "powervs_osa21"
  ibmcloud_api_key = local.key
  region           = "osa"
  zone             = "osa21"
}
