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
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "artifacts-k8s-io-tfstate"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}

# Provider for AWS non-region-specific operations
provider "aws" {
  region = "us-east-2"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

# Per-region providers
provider "aws" {
  alias  = "ap-northeast-1"
  region = "ap-northeast-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "ap-northeast-2"
  region = "ap-northeast-2"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "ap-northeast-3"
  region = "ap-northeast-3"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "ap-south-1"
  region = "ap-south-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "ap-southeast-1"
  region = "ap-southeast-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "ap-southeast-2"
  region = "ap-southeast-2"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "ca-central-1"
  region = "ca-central-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "eu-north-1"
  region = "eu-north-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "eu-west-2"
  region = "eu-west-2"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "eu-west-3"
  region = "eu-west-3"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "sa-east-1"
  region = "sa-east-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "us-west-1"
  region = "us-west-1"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
  assume_role {
    role_arn = var.atlantis_role_arn
  }
}
