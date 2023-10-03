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

/* This file contains:
- AWS accounts used by kOps
*/

module "kops_infra_ci" {
  source       = "../modules/org-account"
  account_name = "kops-infra-ci"
  email        = "k8s-infra-aws-admins+kops-infra-ci@kubernetes.io"
  tags = {
    environment = "prod",
    group       = "sig-cluster-lifecycle"
  }
}

module "kops_infra_services" {
  source       = "../modules/org-account"
  account_name = "kops-infra-services"
  email        = "k8s-infra-aws-admins+kops-infra-services@kubernetes.io"
  tags = {
    environment = "prod"
    group       = "sig-cluster-lifecycle"
  }
}
