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

provider "aws" {
  region = var.region
}

terraform {
  required_version = "~> 1.5.0"

  backend "s3" {
    bucket = "prow-build-canary-cluster-tfstate"
    key    = "iam/eks-prow-iam/terraform.tfstate"
    region = "us-east-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.19"
    }
  }
}

module "eks_prow_iam" {
  source            = "../../modules/eks-prow-iam"
  eks_infra_admins  = var.eks_infra_admins
  eks_infra_viewers = var.eks_infra_admins
}
