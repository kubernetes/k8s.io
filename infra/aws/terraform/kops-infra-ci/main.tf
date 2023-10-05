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
      version = "~> 5.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }

  backend "s3" {
    bucket = "k8s-infra-kops-ci-tf-state"
    region = "us-east-2"
    key    = "kops-infra-ci/terraform.tfstate"
    # TODO(ameukam): stop used hardcoded account id. Preferably use SSO user
    role_arn     = "arn:aws:iam::808842816990:role/OrganizationAccountAccessRole"
    session_name = "kops-infra-ci"
  }
}

provider "aws" {
  region = "us-east-2"

  assume_role {
    role_arn = "arn:aws:iam::${local.kops-infra-ci-account-id}:role/OrganizationAccountAccessRole"
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # This requires the awscli to be installed locally where Terraform is executed.
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

################################################################################
# Common Locals
################################################################################

locals {
  kops-infra-ci-name       = "kops-infra-ci"
  kops-infra-ci-index      = index(data.aws_organizations_organization.current.accounts[*].name, local.kops-infra-ci-name)
  kops-infra-ci-account-id = data.aws_organizations_organization.current.accounts[local.kops-infra-ci-index].id

  prefix = "k8s-infra-kops"
}

################################################################################
# Common Data
################################################################################

data "aws_region" "current" {}
data "aws_organizations_organization" "current" {}
