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

locals {
  audit-account-name  = "k8s-infra-security-audit"
  audit-account-index = index(data.aws_organizations_organization.current.accounts.*.name, local.audit-account-name)
  audit-account-id    = data.aws_organizations_organization.current.accounts[local.audit-account-index].id

  logging-account-name  = "k8s-infra-security-logs"
  logging-account-index = index(data.aws_organizations_organization.current.accounts.*.name, local.logging-account-name)
  logging-account-id    = data.aws_organizations_organization.current.accounts[local.audit-account-index].id
}

data "aws_organizations_organization" "current" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_session_context" "whoami" {
  arn = data.aws_caller_identity.current.arn
}
