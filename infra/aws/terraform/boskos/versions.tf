terraform {
  required_version = "~> 1.11"

  backend "s3" {
    # This S3 bucket is created in eks-e2e-boskos-001 AWS account
    bucket = "eks-e2e-boskos-tfstate"
    key    = "boskos/terraform.tfstate"
    region = "us-west-2"
    assume_role = {
      role_arn = "arn:aws:iam::995654820765:role/OrganizationAccountAccessRole"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }
}
