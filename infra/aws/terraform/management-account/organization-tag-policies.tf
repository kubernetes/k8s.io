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

module "organization_tag_policy_group" {
  source = "../modules/tag-policy"

  tag_name = "group"
  # Values from https://github.com/kubernetes/community/blob/master/sig-list.md
  tag_values = [
    "sig-api-machinery",
    "sig-apps",
    "sig-architecture",
    "sig-auth",
    "sig-autoscaling",
    "sig-cli",
    "sig-cloud-provider",
    "sig-cluster-lifecycle",
    "sig-contributor-experience",
    "sig-docs",
    "sig-instrumentation",
    "sig-k8s-infra",
    "sig-multicluster",
    "sig-network",
    "sig-node",
    "sig-release",
    "sig-scalability",
    "sig-scheduling",
    "sig-security",
    "sig-storage",
    "sig-testing",
    "sig-ui",
    "sig-usability",
    "sig-windows",
    "ug-vmware-users",
    "wg-api-expression",
    "wg-batch",
    "wg-data-protection",
    "wg-iot-edge",
    "wg-multitenancy",
    "wg-policy",
    "wg-reliability",
    "wg-structured-logging"
  ]

  enforce_services = [
    "ec2",
    "eks",
    "ecr",
    "s3"
  ]

  enable_cost_allocation = true

}

module "organization_tag_policy_environment" {
  source = "../modules/tag-policy"

  tag_name = "environment"
  tag_values = [
    "staging",
    "prod"
  ]

  enforce_services = [
    "ec2",
    "eks",
    "ecr",
    "s3"
  ]

  enable_cost_allocation = true

}
