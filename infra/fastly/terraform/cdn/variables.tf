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

variable "bucket_name" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "domain" {
  type = string
}

variable "shield_location" {
  type    = string
  default = "chi-il-us"
}

variable "datadog_config" {
  type = object({
    service_name = string
    env          = string
    token        = string
  })
}

variable "gcs_access_key" {
  type = string
}

variable "gcs_secret_key" {
  type = string
}
