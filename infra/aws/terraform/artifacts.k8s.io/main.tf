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

// prefix prefixes every resource so that the resources
// can be created without using the same names. Useful
// for testing and staging

variable "prefix" {
  type        = string
  default     = "test-"
  description = "The prefix for all resources"

  validation {
    condition     = can(regex(".*-$|^$", var.prefix))
    error_message = "The string must end with a hyphen or be empty."
  }
}

module "bucket_us-east-1" {
  source = "./s3"

  providers = {
    aws = aws.us-east-1
  }

  prefix = var.prefix
}

module "bucket_us-east-2" {
  source = "./s3"

  providers = {
    aws = aws.us-east-2
  }

  prefix = var.prefix
}

module "bucket_us-west-2" {
  source = "./s3"

  providers = {
    aws = aws.us-west-2
  }

  prefix = var.prefix
}

module "bucket_eu-west-2" {
  source = "./s3"

  providers = {
    aws = aws.eu-west-2
  }

  prefix = var.prefix
}

module "bucket_eu-central-1" {
  source = "./s3"

  providers = {
    aws = aws.eu-central-1
  }

  prefix = var.prefix
}

module "bucket_ap-southeast-1" {
  source = "./s3"

  providers = {
    aws = aws.ap-southeast-1
  }

  prefix = var.prefix
}