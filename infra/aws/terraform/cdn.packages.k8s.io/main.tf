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
      version = "~> 5.7"
    }
  }

  backend "s3" {
    bucket       = "cdn-packages-k8s-io-tfstate"
    key          = "terraform.tfstate"
    region       = "eu-central-1"
    role_arn     = "arn:aws:iam::309501585971:role/Provisioner"
    session_name = "cdn-packages-k8s-io-terraform"
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn     = "arn:aws:iam::309501585971:role/Provisioner"
    session_name = "cdn-packages-k8s-io-terraform"
  }
}

# ACM certificate for CloudFront distribution must be created in us-east-1 (required by AWS)
provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::309501585971:role/Provisioner"
    session_name = "cdn-packages-k8s-io-terraform"
  }
}

################################################################################
# Common Locals
################################################################################

locals {
  account_id = data.aws_caller_identity.current.account_id

  prefix = "${terraform.workspace}-"

  tags = {
    project = "cdn.packages.k8s.io"
  }
}

################################################################################
# Common Data
################################################################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
