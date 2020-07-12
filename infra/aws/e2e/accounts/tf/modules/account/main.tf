provider "aws" {
  version             = "~> 2.0"
  region              = "us-east-1"
  allowed_account_ids = ["768319786644"] # Create in the main CNCF account
}

resource "aws_organizations_account" "main" {
  name  = var.id
  email = var.email
}


