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

variable "project_id" {
  type    = string
  default = ""
  validation {
    condition     = length(var.project_id) > 0
    error_message = "Must specify project_id variable."
  }
}

variable "bucket_name" {
  type    = string
  default = ""
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "storage_class" {
  type        = string
  description = "Storage class for TUF root bucket."
  default     = "STANDARD"
  validation {
    condition = contains(["STANDARD", "MULTI_REGIONAL", "REGIONAL"], var.storage_class)
    error_message = "The storage class is invalid"
  }
}

variable "public_access_prevention" {
  description = "Prevents public access to a bucket. Acceptable values are inherited or enforced."
  type        = string
  default     = "inherited"
  validation {
      condition = contains(["enforced", "inherited"], var.public_access_prevention)
      error_message = "Must specify PROJECT_ID variable."
  }
}
