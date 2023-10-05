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
# VPC
###############################################

# VPC is IPv4/IPv6 Dual-Stack, but our cluster is IPv4 because EKS doesn't
# support dual-stack yet.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1"

  name = "${var.cluster_name}-vpc"

  cidr                  = var.vpc_cidr
  secondary_cidr_blocks = var.vpc_secondary_cidr_blocks

  azs             = local.azs
  private_subnets = var.vpc_private_subnet
  public_subnets  = var.vpc_public_subnet

  # intra_subnets are private subnets without the internet access 
  # (https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest#private-versus-intra-subnets)
  intra_subnets = var.vpc_intra_subnet

  # Enable public IPv4 addresses
  map_public_ip_on_launch = true

  # Enable IPv6
  enable_ipv6            = true
  create_egress_only_igw = true

  # Assign IPv6 address on creation to each instance
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_assign_ipv6_address_on_creation = true
  intra_subnet_assign_ipv6_address_on_creation   = true

  # Used for calculating IPv6 CIDR based on the following formula:
  # cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, var.private_subnet_ipv6_prefixes[count.index])
  private_subnet_ipv6_prefixes = [0, 1, 2]
  public_subnet_ipv6_prefixes  = [3, 4, 5]
  intra_subnet_ipv6_prefixes   = [6, 7, 8]

  # NAT Gateway allows connection to external services (e.g. Internet).
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Tags to allow ELB (Elastic Load Balancing).
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  tags = local.tags
}
