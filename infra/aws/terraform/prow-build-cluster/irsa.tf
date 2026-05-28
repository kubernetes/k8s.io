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

###############################################
# IAM
###############################################

# IAM policy used for the AWS VPC CNI plugin.
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.6"

  name            = "VPC-CNI-IRSA"
  use_name_prefix = true

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  vpc_cni_enable_ipv6   = true
  permissions_boundary  = data.aws_iam_policy.eks_resources_permission_boundary.arn

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

# IAM policy used for the AWS EBS CSI driver plugin.
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.6"

  name            = "EBS-CSI-IRSA"
  use_name_prefix = true

  attach_ebs_csi_policy = true
  permissions_boundary  = data.aws_iam_policy.eks_resources_permission_boundary.arn

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

# IAM policy used for AWS Load Balancer Controller.
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.6"

  name            = "LBCONTROLLER-IRSA"
  use_name_prefix = true

  attach_load_balancer_controller_policy = true
  permissions_boundary                   = data.aws_iam_policy.eks_resources_permission_boundary.arn

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

# IAM policy used for Secrets Manager and accessing secrets.
# Example policy, uncomment and modify as needed.
module "secrets_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.6"

  name            = "SECRETSMANAGER-IRSA"
  use_name_prefix = true

  policies = {
    secrets_manager = aws_iam_policy.secretsmanager_read.arn,
  }

  permissions_boundary = data.aws_iam_policy.eks_resources_permission_boundary.arn

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = local.tags
}
