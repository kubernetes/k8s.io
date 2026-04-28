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

module "us-west-1" {
  source = "./s3"

  providers = {
    aws = aws.us-west-1
  }

  prefix = var.prefix
}

module "us-west-2" {
  source = "./s3"

  providers = {
    aws = aws.us-west-2
  }

  prefix = var.prefix
}

module "us-east-1" {
  source = "./s3"

  providers = {
    aws = aws.us-east-1
  }

  prefix = var.prefix
}

module "us-east-2" {
  source = "./s3"

  providers = {
    aws = aws.us-east-2
  }

  prefix = var.prefix

  s3_replication_iam_role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3writer"

  s3_replication_rules = [
    {
      id                               = "registry-k8s-io-us-east-2-to-registry-k8s-io-us-west-1"
      status                           = "Enabled"
      priority                         = 1
      destination_bucket_arn           = "arn:aws:s3:::${var.prefix}registry-k8s-io-us-west-1"
      destination_bucket_storage_class = "STANDARD"
    },
    {
      id                               = "registry-k8s-io-us-east-2-to-registry-k8s-io-us-west-2"
      status                           = "Enabled"
      priority                         = 2
      destination_bucket_arn           = "arn:aws:s3:::${var.prefix}registry-k8s-io-us-west-2"
      destination_bucket_storage_class = "STANDARD"
    },
    {
      id                               = "registry-k8s-io-us-east-2-to-registry-k8s-io-us-east-1"
      status                           = "Enabled"
      priority                         = 3
      destination_bucket_arn           = "arn:aws:s3:::${var.prefix}registry-k8s-io-us-east-1"
      destination_bucket_storage_class = "STANDARD"
    },
    {
      id                               = "registry-k8s-io-us-east-2-to-registry-k8s-io-eu-west-1"
      status                           = "Enabled"
      priority                         = 4
      destination_bucket_arn           = "arn:aws:s3:::${var.prefix}registry-k8s-io-eu-west-1"
      destination_bucket_storage_class = "STANDARD"
    },
    {
      id                               = "registry-k8s-io-us-east-2-to-registry-k8s-io-eu-central-1"
      status                           = "Enabled"
      priority                         = 5
      destination_bucket_arn           = "arn:aws:s3:::${var.prefix}registry-k8s-io-eu-central-1"
      destination_bucket_storage_class = "STANDARD"
    },
    {
      id                               = "registry-k8s-io-us-east-2-to-registry-k8s-io-ap-southeast-1"
      status                           = "Enabled"
      priority                         = 6
      destination_bucket_arn           = "arn:aws:s3:::${var.prefix}registry-k8s-io-ap-southeast-1"
      destination_bucket_storage_class = "STANDARD"
    },
    {
      id                               = "registry-k8s-io-us-east-2-to-registry-k8s-io-ap-northeast-1"
      status                           = "Enabled"
      priority                         = 7
      destination_bucket_arn           = "arn:aws:s3:::${var.prefix}registry-k8s-io-ap-northeast-1"
      destination_bucket_storage_class = "STANDARD"
    },
    {
      id                               = "registry-k8s-io-us-east-2-to-registry-k8s-io-ap-south-1"
      status                           = "Enabled"
      priority                         = 8
      destination_bucket_arn           = "arn:aws:s3:::${var.prefix}registry-k8s-io-ap-south-1"
      destination_bucket_storage_class = "STANDARD"
    },
  ]
}

module "eu-west-1" {
  source = "./s3"

  providers = {
    aws = aws.eu-west-1
  }

  prefix = var.prefix
}

module "eu-central-1" {
  source = "./s3"

  providers = {
    aws = aws.eu-central-1
  }

  prefix = var.prefix
}

module "ap-southeast-1" {
  source = "./s3"

  providers = {
    aws = aws.ap-southeast-1
  }

  prefix = var.prefix
}

module "ap-northeast-1" {
  source = "./s3"

  providers = {
    aws = aws.ap-northeast-1
  }

  prefix = var.prefix
}

module "ap-south-1" {
  source = "./s3"

  providers = {
    aws = aws.ap-south-1
  }

  prefix = var.prefix
}
