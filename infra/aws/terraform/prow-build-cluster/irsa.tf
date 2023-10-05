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
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name_prefix              = "VPC-CNI-IRSA"
  attach_vpc_cni_policy         = true
  vpc_cni_enable_ipv4           = true
  vpc_cni_enable_ipv6           = true
  role_permissions_boundary_arn = data.aws_iam_policy.eks_resources_permission_boundary.arn

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
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name_prefix              = "EBS-CSI-IRSA"
  attach_ebs_csi_policy         = true
  role_permissions_boundary_arn = data.aws_iam_policy.eks_resources_permission_boundary.arn

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
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name_prefix                       = "LBCONTROLLER-IRSA"
  attach_load_balancer_controller_policy = true
  role_permissions_boundary_arn          = data.aws_iam_policy.eks_resources_permission_boundary.arn

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

# IAM policy used for Cluster Autoscaler.
module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name_prefix                 = "AUTOSCALER-IRSA"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [module.eks.cluster_name]
  role_permissions_boundary_arn    = data.aws_iam_policy.eks_resources_permission_boundary.arn

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = local.tags
}

# IAM policy used for Secrets Manager and accessing secrets.
# Example policy, uncomment and modify as needed.
module "secrets_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "SECRETSMANAGER-IRSA"
  role_policy_arns = {
    secrets_manager = aws_iam_policy.secretsmanager_read.arn,
  }

  role_permissions_boundary_arn = data.aws_iam_policy.eks_resources_permission_boundary.arn

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = local.tags
}
