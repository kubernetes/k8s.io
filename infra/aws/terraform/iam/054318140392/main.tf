data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "prow-build-canary-cluster-tfstate"
    key    = "iam/terraform.tfstate"
    region = "us-east-2"
  }
}
