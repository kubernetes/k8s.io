/*
Copyright 2022 The Kubernetes Authors.

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

# Required variables
variable "domain" {
  description = "The google_monitoring_uptime_check_config ID to associate with"
  type        = string
}
variable "notification_channels" {
  description = "A list of channels to send alert notifications to"
  type        = list(any)
}
variable "documentation_text" {
  description = "A text included with the alert"
  type        = string
}

# Optional variables
variable "failing_duration" {
  description = "The amount of time in seconds that the check has to fail before it alerts"
  type        = number
  default     = 120
}
variable "trigger_percent" {
  description = "The percent of alerts that are failing before the alert triggers"
  type        = number
  default     = null
}

variable "project_id" {
  type = string
  validation {
    condition     = length(var.project_id) > 6 && length(var.project_id) <=30
    error_message = "Must specify PROJECT_ID variable."
  }
}
