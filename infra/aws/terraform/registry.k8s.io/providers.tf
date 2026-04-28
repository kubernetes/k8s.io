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

terraform {
  backend "s3" {
    bucket = "registry-k8s-io-tfstate"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }

  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# The role_arn (arn:aws:iam::513428760722:role/registry.k8s.io_s3admin)
# used in each provider block is managed in
# https://github.com/cncf-infra/aws-infra/blob/2ac2e63c162134a9e6036d84beee2d5adf6b4ff2/terraform/iam/main.tf

provider "aws" {
  region = "us-west-1"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}

provider "aws" {
  alias  = "us-west-1"
  region = "us-west-1"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}

provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}

provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}

provider "aws" {
  alias  = "ap-southeast-1"
  region = "ap-southeast-1"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}

provider "aws" {
  alias  = "ap-northeast-1"
  region = "ap-northeast-1"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}

provider "aws" {
  alias  = "ap-south-1"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3admin"
  }
}
