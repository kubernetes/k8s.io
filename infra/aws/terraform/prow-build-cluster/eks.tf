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
# EKS Cluster
###############################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16"

  # General cluster properties.
  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true

  # Manage aws-auth ConfigMap.
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

  iam_role_permissions_boundary = data.aws_iam_policy.eks_resources_permission_boundary.arn

  # Allow access to the KMS key used for secrets encryption to the root account.
  kms_key_administrators = [
    local.root_account_arn
  ]
  # Allow service access to the KMS key to the EKSInfraAdmin role.
  kms_key_service_users = [
    data.aws_iam_role.eks_infra_admin.arn
  ]

  # We use IPv4 for the best compatibility with the existing setup.
  # Additionally, Ubuntu EKS optimized AMI doesn't support IPv6 well.
  cluster_ip_family = "ipv4"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  node_security_group_additional_rules = var.bastion_install ? {
    bastion_22 = {
      description              = "Bastion host to nodes"
      protocol                 = "tcp"
      from_port                = 22
      to_port                  = 22
      type                     = "ingress"
      source_security_group_id = aws_security_group.bastion_host_security_group[0].id
    }
  } : null

  eks_managed_node_group_defaults = {
    # TODO(xmudrii-ubuntu): Temporarily disabled because it's not supported by Bottlerocket Linux
    # enable_bootstrap_user_data = true

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = false
  }

  eks_managed_node_groups = {
    stable           = local.node_group_stable
    build-us-east-2a = local.node_group_build_us_east_2a
    build-us-east-2b = local.node_group_build_us_east_2b
    build-us-east-2c = local.node_group_build_us_east_2c
  }
}
