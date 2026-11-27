/*
Copyright 2026 The Kubernetes Authors.

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
  default     = "us-west-2"
}

variable "sender_email" {
  description = "SES email identity used as sender"
  type        = string
}

variable "recipient_email" {
  description = "Email address that receives the notification when no_mock is true"
  type        = string
}

variable "no_mock" {
  description = "Send the notification to recipient_email. When false, it is only sent to sender_email"
  type        = bool
  default     = false
}

variable "days_to_alert" {
  description = "How many calendar days before the cherry-pick deadline to send the notification"
  type        = number

  validation {
    condition     = var.days_to_alert >= 0 && floor(var.days_to_alert) == var.days_to_alert
    error_message = "days_to_alert must be a non-negative integer."
  }
}

variable "schedule_path" {
  description = "https URL of the patch release schedule.yaml"
  type        = string

  validation {
    condition     = startswith(var.schedule_path, "https://")
    error_message = "schedule_path must be an https:// URL."
  }
}

variable "schedule_expression" {
  description = "EventBridge schedule expression that triggers the Lambda (UTC)"
  type        = string
  default     = "cron(0 16 * * ? *)"
}

variable "image_uri" {
  description = "Lambda container image, pinned by digest (<repository_url>@sha256:...)"
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.image_uri))
    error_message = "image_uri must be pinned by digest (…@sha256:<digest>)."
  }
}

variable "alert_email" {
  description = "Email address notified when the Lambda fails. Leave empty to disable alerting"
  type        = string
  default     = ""
}
