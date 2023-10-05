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
  description = "Name for health-check and associated alarm"
  type        = string
}

variable "fqdn" {
  description = "Destination domain to check"
  type        = string
}

variable "resource_path" {
  description = "Health check resource path"
  type        = string
  default     = ""
}

variable "port" {
  description = "HTTP port to check"
  type        = number
  default     = 443
}

variable "request_interval" {
  description = "Health check request interval"
  type        = string
  default     = "30"
}

variable "regions" {
  description = "AWS regions - us-east-1 | us-west-1 | us-west-2 | eu-west-1 | ap-southeast-1 | ap-southeast-2 | ap-northeast-1 | sa-east-1"
  type        = list(string)
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
  description = "Enable or Disable the healthcheck - disabled set target as always healthy"
  type        = bool
  default     = false
}

variable "failure_threshold" {
  description = "The number of consecutive health checks that an endpoint must pass or fail"
  type        = string
  default     = "5"
}

variable "alarm_period" {
  description = "The period in seconds over which the specified statistic is applied. Valid values are 10, 30, or any multiple of 60"
  type        = string
  default     = "60"
}

variable "sns_arn" {
  description = "AWS SNS Arn to alert the relevant group"
  type        = string
}
