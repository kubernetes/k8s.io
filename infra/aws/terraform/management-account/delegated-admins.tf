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

# https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services_list.html

resource "aws_organizations_delegated_administrator" "config_multiaccount" {
  account_id        = module.security_audit.account_id
  service_principal = "config-multiaccountsetup.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "config" {
  account_id        = module.security_audit.account_id
  service_principal = "config.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "guardduty" {
  account_id        = module.security_audit.account_id
  service_principal = "guardduty.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "access_analyzer" {
  account_id        = module.security_audit.account_id
  service_principal = "access-analyzer.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "securityhub" {
  account_id        = module.security_audit.account_id
  service_principal = "securityhub.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "fms" {
  account_id        = module.security_audit.account_id
  service_principal = "fms.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "detective" {
  account_id        = module.security_audit.account_id
  service_principal = "detective.amazonaws.com"
}
