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

module "eks" {
  providers = { aws = aws.kops-infra-ci }
  source    = "terraform-aws-modules/eks/aws"
  version   = "21.3.2"

  name                   = local.cluster_name
  kubernetes_version     = var.eks_version
  endpoint_public_access = true

  ip_family = "ipv4"

  # Give the Terraform identity admin access to the cluster
  # which will allow resources to be deployed into the cluster
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  enabled_log_types = [
    "audit",
    "authenticator",
    "api",
    "controllerManager",
    "scheduler"
  ]

  cloudwatch_log_group_retention_in_days = 30

  addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      before_compute           = true
      most_recent              = true
      service_account_role_arn = module.vpc_cni_irsa.arn
      # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.arn
    }
  }

  eks_managed_node_groups = {
    prow-build = {
      name            = "prow-build"
      description     = "EKS managed node group used to run kops jobs"
      use_name_prefix = true

      dataplane_wait_duration = "600s"

      subnet_ids = module.vpc.private_subnets

      min_size = 3
      max_size = 100

      # Force version update if existing pods are unable to be drained due to a PodDisruptionBudget issue
      force_update_version = true
      update_config = {
        max_unavailable = 3
      }

      capacity_type  = "ON_DEMAND"
      instance_types = ["c7a.4xlarge"]
      ami_type       = "BOTTLEROCKET_x86_64"

      ebs_optimized     = true
      enable_monitoring = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            iops                  = "3000" #https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-optimized.html
            encrypted             = false
            delete_on_termination = true
          }
        }
      }

      bootstrap_extra_args = <<-EOT
      # Bootstrap the instance using our bootstrap script embeded in a Docker image
      [settings.bootstrap-containers.bootstrap]
      source = "${aws_ecr_repository.repo.repository_url}:v0.0.1"
      mode = "always"
      essential = true
    EOT

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
        instance_metadata_tags      = "enabled"
      }

      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  tags = merge(var.tags, {
    "region" = data.aws_region.current.region
  })
}

//TODO(ameukam): Use access entries
module "eks-auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::468814281478:role/Prow-EKS-Admin"
      username = "arn:aws:iam::468814281478:role/Prow-EKS-Admin"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_organizations_organization.current.id}:user/ameukam"
      username = "ameukam"
      groups   = ["system:masters"]
    },
  ]
}

resource "aws_eks_pod_identity_association" "kops_prow_build" {
  provider = aws.kops-local-ci

  cluster_name    = module.eks.cluster_name
  namespace       = "test-pods"
  service_account = "prowjob-default-sa"
  role_arn        = aws_iam_role.eks_pod_identity_role.arn
}


module "vpc_cni_irsa" {
  providers = { aws = aws.kops-infra-ci }
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version   = "~> 6.2.1"

  name                  = "vpc-cni-ipv4"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  # We use IPv4-based EKS cluster, so we don't need this
  vpc_cni_enable_ipv6 = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = var.tags
}

module "ebs_csi_irsa" {
  providers = { aws = aws.kops-infra-ci }
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version   = "~> 6.2.1"

  name                  = "ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

module "cluster_autoscaler_irsa_role" {
  providers = { aws = aws.kops-infra-ci }
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version   = "~> 6.2.1"

  name                             = "cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = var.tags
}
