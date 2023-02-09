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

variable "deletion_window_in_days" {
  type        = number
  default     = 30
  description = "Delay in days after which the key is deleted"
}

variable "description" {
  type        = string
  description = "The description of the key as viewed in AWS console"
}

variable "enable_key_rotation" {
  type        = bool
  default     = true
  description = "Specifies whether key rotation is enabled"
}

variable "name" {
  type        = string
  description = "The name of the key"
}

variable "policy" {
  type        = string
  nullable = false
  description = "A valid KMS policy JSON document"
  validation {
    condition = can(jsondecode(var.policy))
    error_message = "KMS key policy must be a JSON document."
  }
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the key"
}
