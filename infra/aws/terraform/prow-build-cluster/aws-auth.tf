/*
Copyright 2024 The Kubernetes Authors.

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

module "aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.20"

  manage_aws_auth_configmap = true

  # Configure aws-auth
  aws_auth_roles = local.aws_auth_roles

  # Allow EKS access to the root account.
  aws_auth_users = [
    {
      "userarn"  = local.root_account_arn
      "username" = "root"
      "groups" = [
        "eks-cluster-admin"
      ]
    },
  ]

}
