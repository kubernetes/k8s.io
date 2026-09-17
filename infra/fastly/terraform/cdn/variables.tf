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

variable "bucket_configs" {
  description = "List of origin buckets to serve from"
  type = list(object({
    name           = string
    release_bucket = optional(bool, false)
    public         = optional(bool, false)
  }))
  default = []
}

variable "cloud" {
  description = "Cloud hosting the origin buckets"
  type        = string
  default     = "gcp"
  validation {
    condition     = contains(["gcp", "aws"], var.cloud)
    error_message = "cloud must be one of: gcp, aws"
  }
}

variable "aws_region" {
  description = "Region of the S3 origin buckets, used when cloud is aws"
  type        = string
  default     = "us-east-2"
}

variable "domain" {
  type = string
}

variable "cache_ttl" {
  description = "Default cache TTL for the CDN"
  type        = number
  default     = 86400
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

variable "access_key" {
  description = "HMAC access key ID used to sign origin requests"
  type        = string
  default     = null
}

variable "secret_key" {
  description = "HMAC secret key used to sign origin requests"
  type        = string
  default     = null
  sensitive   = true
}
