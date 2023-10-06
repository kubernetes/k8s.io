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

variable "prefix" {
  description = "Prefix added to bucket name"
  type        = string
  default     = ""
  nullable    = false
}

variable "s3_replication_iam_role_arn" {
  description = "IAM role assumed by S3 service for replication"
  type        = string
  default     = null
}

variable "s3_replication_rules" {
  description = "List of maps for S3 replication rules"
  type        = list(map(string))
  default     = []
  nullable    = false
}
