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


module "infra_shared_services" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-shared-services"
  email                      = "k8s-infra-aws-admins+infra-shared-services@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.infrastructure.id
}

module "infra_network" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-networking"
  email                      = "k8s-infra-aws-admins+infra-networking@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.infrastructure.id
}
