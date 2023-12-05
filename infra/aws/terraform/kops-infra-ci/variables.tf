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

variable "eks_version" {
  type    = string
  default = "1.27"
}

variable "tags" {
  type = map(string)
  default = {
    "managed-by" = "Terraform",
    "group"      = "sig-cluster-lifecycle",
    "subproject" = "kops"
    "githubRepo" = "git.k8s.io/k8s.io"
  }
}

variable "region" {
  type    = string
  default = "us-east-2"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC"
  default     = "10.128.0.0/16"
}
