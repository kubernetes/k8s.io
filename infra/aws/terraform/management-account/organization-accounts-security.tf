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

module "security_audit" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-security-audit"
  email                      = "k8s-infra-aws-admins+security-audit@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.security.id
}

module "security_engineering" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-security-engineering"
  email                      = "k8s-infra-aws-admins+security-engineering@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.security.id
}

module "security_incident_response" {
  source = "../modules/org-account"

  account_name = "k8s-infra-security-incident-response"
  email        = "k8s-infra-aws-admins+security-incident-response@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.security.id
}

module "security_logs" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-security-logs"
  email                      = "k8s-infra-aws-admins+security-logs@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.security.id
}
