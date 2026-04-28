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

variable "name" {
  type        = string
  description = "Name for health-check and associated alarm"
}

variable "fqdn" {
  type        = string
  description = "Destination domain to check"
}

variable "resource_path" {
  type        = string
  description = "Health check resource path"
  default     = ""
}

variable "port" {
  type        = number
  description = "HTTP port to check"
  default     = 443
}

variable "request_interval" {
  type        = string
  description = "Health check request interval"
  default     = "30"
}

variable "regions" {
  type        = list(string)
  description = "AWS regions - us-east-1 | us-west-1 | us-west-2 | eu-west-1 | ap-southeast-1 | ap-southeast-2 | ap-northeast-1 | sa-east-1"
  default = [
    "us-east-1",
    "us-west-1",
    "us-west-2",
    "eu-west-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "ap-northeast-1",
    "sa-east-1"
  ]
}

variable "disabled" {
  type        = bool
  description = "Enable or Disable the healthcheck - disabled set target as always healthy"
  default     = false
}

variable "failure_threshold" {
  type        = string
  description = "The number of consecutive health checks that an endpoint must pass or fail."
  default     = "5"
}

variable "alarm_period" {
  type        = string
  description = "The period in seconds over which the specified statistic is applied. Valid values are 10, 30, or any multiple of 60"
  default     = "60"
}

variable "sns_arn" {
  type        = string
  description = "AWS SNS Arn to alert the relevant group"
}
