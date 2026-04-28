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

terraform {
  required_version = "~> 1.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.22.1"
    }
  }

  backend "s3" {
    bucket = "k8-infra-macos-tfstate"
    key    = "terraform.state"
    region = "us-east-2"
  }
}

provider "aws" {
  region = "us-east-2"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
  default_tags {
    tags = {
      Environment = "prod"
      group       = "sig-k8s-infra"
    }
  }
}
