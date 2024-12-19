/*
Copyright 2024 The Kubernetes Authors.

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

variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
}

variable "email_identity" {
  description = "The email address or domain to verify"
  type        = string
}

variable "to_email" {
  description = "The email address to send the notification"
  type        = string
}

variable "no_mock" {
  description = "if will send the message to dev@kubernetes.io or just internal"
  type        = bool
}

variable "days_to_alert" {
  description = "when to send the notification"
  type        = number
}

variable "schedule_path" {
  description = "path where we can find the schedule.yaml"
  type        = string
}

variable "repository" {
  description = "The ECR repository to use for the image"
  type        = string
  default     = ""
}
