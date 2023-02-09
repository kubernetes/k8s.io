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

#############################################################################
# Project

variable "org_name" {
  type        = string
  description = "Name of the AWS Organization"
  default     = "k8s-infra"
}

variable "region" {
  type     = string
  default  = "us-east-2"
  nullable = false
}

#############################################################################
# Cloudtrail

variable "cloudtrail_name" {
  type        = string
  description = "Name of the Cloudtrail"
  nullable    = false
}

variable "cloudtrail_trail_name" {
  type        = string
  description = "Bucket name of Cloudtrail logs"
  nullable    = false
}

variable "cloudtrail_logging" {
  type        = bool
  description = "Enables logging for the trail"
  default     = true
  nullable    = false
}

#############################################################################
# SNS

variable "cloudtrail_topic_arn" {
  type        = string
  description = "ARN of the SNS topic where information about newly shipped CloudTrail log files are sent"
}

#############################################################################
# Commons

variable "tags" {
  type        = map(string)
  description = "Tags applied to AWS resources"
  default = {
    managed-by = "Terraform"
  }
}
