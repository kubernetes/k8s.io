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
  backend "s3" {
    bucket = "k8s-infra-registry-k8s-io-tf-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.33.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
  alias  = "networking"

  assume_role {
    role_arn = "arn:aws:iam::${local.networking-account-id}:role/OrganizationAccountAccessRole"
  }
}

# Provider for AWS non-region-specific operations
provider "aws" {
  region = "us-east-2"
}

provider "aws" {
  alias  = "registry-k8s-io-prod"
  region = "us-east-2"

  assume_role {
    role_arn = local.assume_role_arn
  }
}

provider "aws" {
  alias  = "ca-central-1"
  region = "ca-central-1"

  assume_role {
    role_arn = local.assume_role_arn
  }
}


provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  assume_role {
    role_arn = local.assume_role_arn
  }
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"

  assume_role {
    role_arn = local.assume_role_arn
  }
}

provider "aws" {
  alias  = "us-west-1"
  region = "us-west-1"

  assume_role {
    role_arn = local.assume_role_arn
  }
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"

  assume_role {
    role_arn = local.assume_role_arn
  }
}
