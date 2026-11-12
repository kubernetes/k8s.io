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

terraform {
  # The bucket and the Provisioner role are created by
  # infra/aws/cloudformation/iam/sig-release
  backend "s3" {
    bucket       = "k8s-sig-release-tfstate"
    key          = "patch-release-notification/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true

    assume_role = {
      role_arn     = "arn:aws:iam::433650573627:role/Provisioner"
      session_name = "patch-release-notification-terraform"
    }
  }

  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn     = "arn:aws:iam::433650573627:role/Provisioner"
    session_name = "patch-release-notification-terraform"
  }

  default_tags {
    tags = {
      group       = "sig-release"
      environment = "prod"
      service     = "patch-release-notification"
    }
  }
}
