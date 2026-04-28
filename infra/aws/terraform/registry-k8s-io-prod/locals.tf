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

locals {
  assume_role_arn = "arn:aws:iam::${local.registry_k8s_io_prod_account_id}:role/OrganizationAccountAccessRole"

  audit-account-name  = "k8s-infra-security-audit"
  audit-account-index = index(data.aws_organizations_organization.current.accounts.*.name, local.audit-account-name)
  audit-account-id    = data.aws_organizations_organization.current.accounts[local.audit-account-index].id

  logging-account-name  = "k8s-infra-security-logs"
  logging-account-index = index(data.aws_organizations_organization.current.accounts.*.name, local.logging-account-name)
  logging-account-id    = data.aws_organizations_organization.current.accounts[local.logging-account-index].id

  networking-account-name  = "k8s-infra-networking"
  networking-account-index = index(data.aws_organizations_organization.current.accounts.*.name, local.networking-account-name)
  networking-account-id    = data.aws_organizations_organization.current.accounts[local.networking-account-index].id

  registry-k8s-io-prod-name       = "k8s-infra-registry-k8s-io-prod"
  registry_k8s_io_prod_ci_index   = index(data.aws_organizations_organization.current.accounts[*].name, local.registry-k8s-io-prod-name)
  registry_k8s_io_prod_account_id = data.aws_organizations_organization.current.accounts[local.registry_k8s_io_prod_ci_index].id
}
