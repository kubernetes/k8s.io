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

# playground account to experiment e2e tests on AWS
module "aws-playground-01" {
  source = "../modules/org-account"

  account_name = "k8s-infra-e2e-aws-playground-01"
  email        = "k8s-infra-aws-admins+aws-playground-01@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.non_production.id
  tags = {
    "production" = "false",
    "owners"     = "upodroid",
    "group"      = "sig-k8s-infra"
  }
}

#  account used to create and main a canary cluster as build cluster for prow
module "prow_canary" {
  source = "../modules/org-account"

  account_name = "k8s-infra-prow-canary"
  email        = "k8s-infra-aws-admins+prow_canary@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.non_production.id
  tags = {
    "production"  = "false",
    "environment" = "canary",
    "owners"      = "xmudrii",
    "group"       = "sig-k8s-infra",
    "service"     = "eks"
  }
}

# Shared AWS account used for kops/eks related repositories
module "k8s_infra_eks_e2e_shared_001" {
  source = "../modules/org-account"

  account_name = "k8s_infra_eks_e2e_shared_001"
  email        = "k8s-infra-aws-admins+eks_e2e_shared_001@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.non_production.id
  tags = {
    "production" = "false",
    "owners"     = "dims",
    "group"      = "sig-k8s-infra"
  }
}

# Shared AWS account used for kops/eks related repositories
module "windows_operational_readiness" {
  source = "../modules/org-account"

  account_name = "windows_operational_readiness"
  email        = "k8s-infra-aws-admins+windows_operational_readiness@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.non_production.id
  tags = {
    "production" = "false",
    "owners"     = "jayunit100",
    "group"      = "sig-windows"
  }
}
