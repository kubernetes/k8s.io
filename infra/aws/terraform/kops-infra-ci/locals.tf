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
  kops-infra-ci-name       = "kops-infra-ci"
  kops-infra-ci-index      = index(data.aws_organizations_organization.current.accounts.*.name, local.kops-infra-ci-name)
  kops-infra-ci-account-id = data.aws_organizations_organization.current.accounts[local.kops-infra-ci-index].id
}