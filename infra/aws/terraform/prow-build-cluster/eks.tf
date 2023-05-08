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
  version = "19.10.0"

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

  iam_role_permissions_boundary = "arn:aws:iam::${local.account_id}:policy/ProvisionerPermissionBoundary"

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

  eks_managed_node_group_defaults = {
    ami_id                     = var.node_ami
    enable_bootstrap_user_data = true
    instance_types             = var.node_instance_types

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = false
  }

  eks_managed_node_groups = {
    # Build cluster node group.
    build = {
      name            = "build-managed"
      description     = "EKS managed node group used for build nodes"
      use_name_prefix = true

      subnet_ids = module.vpc.private_subnets

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      ami_id                     = var.node_ami
      enable_bootstrap_user_data = true

      force_update_version = false
      update_config = {
        max_unavailable_percentage = var.node_max_unavailable_percentage
      }

      pre_bootstrap_user_data = file("${path.module}/bootstrap/node_bootstrap.sh")

      capacity_type  = "ON_DEMAND"
      instance_types = var.node_instance_types

      ebs_optimized     = true
      enable_monitoring = true

      block_device_mappings = {
        # This must be sda1 in order to match the root volume,
        # otherwise a new volume is created.
        sda1 = {
          device_name = "/dev/sda1"
          ebs = {
            volume_size           = var.node_volume_size
            volume_type           = "gp3"
            iops                  = 16000 # Maximum for gp3 volume.
            throughput            = 1000  # Maximum for gp3 volume.
            encrypted             = false
            delete_on_termination = true
          }
        }
      }

      enclave_options = {
        enabled = true
      }

      tags = local.node_group_tags
    }
  }
}
