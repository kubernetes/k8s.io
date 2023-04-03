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

// this one is overridden to the latest image in staging typically
variable "digest" {
  type     = string
  default  = "sha256:6a37089e595e62636d401b8d93dc8f9c41dca395ecf7386d456484a3cf889b42"
  nullable = false
}
// these should all be explicitly set for both prod and staging
variable "domain" {
  type = string
}
variable "project_id" {
  type = string
}
variable "verbosity" {
  type = string
}
variable "notification_channel_id" {
  type = string
}

variable "service_account_name" {
  type = string
}
