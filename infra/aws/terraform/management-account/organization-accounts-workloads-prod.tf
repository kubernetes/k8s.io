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

module "artifacts-k8s-io" {
  source = "../modules/org-account"

  account_name = "k8s-infra-artifacts-k8s-io-prod"
  email        = "k8s-infra-aws-admins+artifacts-k8s-io-prod@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.production.id
}

module "registry-k8s-io" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-registry-k8s-io-prod"
  email                      = "k8s-infra-aws-admins+registry-k8s-io-prod@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.production.id
}


module "prow_prod" {
  source = "../modules/org-account"

  account_name = "k8s-infra-prow"
  email        = "k8s-infra-aws-admins+prow@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.production.id
  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "eks"
  }
}

module "obs-k8s-io" {
  source = "../modules/org-account"

  account_name = "k8s-infra-obs-k8s-io-prod"
  email        = "k8s-infra-aws-admins+obs-k8s-io-prod@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.production.id
  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-release",
    "service"     = "obs"
  }
}
