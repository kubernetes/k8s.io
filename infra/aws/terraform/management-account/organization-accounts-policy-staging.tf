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

module "policy_staging_account_1" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-policy-staging-account-1"
  email                      = "k8s-infra-aws-admins+policy-staging-account-1@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.policy_staging.id
}

resource "aws_organizations_policy_attachment" "policy_staging_tag_policy_group" {
  policy_id = module.organization_tag_policy_group.tag_policy_id
  target_id = aws_organizations_organizational_unit.policy_staging.id
}

resource "aws_organizations_policy_attachment" "policy_staging_require_tag_group" {
  policy_id = module.organization_tag_policy_group.scp_require_tag_id
  target_id = aws_organizations_organizational_unit.policy_staging.id
}

resource "aws_organizations_policy_attachment" "policy_staging_deny_tag_deletion_group" {
  policy_id = module.organization_tag_policy_group.scp_deny_tag_deletion_id
  target_id = aws_organizations_organizational_unit.policy_staging.id
}

resource "aws_organizations_policy_attachment" "policy_staging_tag_policy_environment" {
  policy_id = module.organization_tag_policy_environment.tag_policy_id
  target_id = aws_organizations_organizational_unit.policy_staging.id
}

resource "aws_organizations_policy_attachment" "policy_staging_require_tag_environment" {
  policy_id = module.organization_tag_policy_environment.scp_require_tag_id
  target_id = aws_organizations_organizational_unit.policy_staging.id
}

resource "aws_organizations_policy_attachment" "policy_staging_deny_tag_deletion_environment" {
  policy_id = module.organization_tag_policy_environment.scp_deny_tag_deletion_id
  target_id = aws_organizations_organizational_unit.policy_staging.id
}
