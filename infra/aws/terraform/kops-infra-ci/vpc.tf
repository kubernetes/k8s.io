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
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = cidrsubnets(local.partition[0], 2, 2, 2)
  public_subnets  = cidrsubnets(local.partition[1], 2, 2, 2)
  partition       = cidrsubnets(aws_vpc_ipam_preview_next_cidr.main.cidr, 2, 2, 2)
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc_ipam" "main" {
  description = "${local.prefix}-${data.aws_region.current.name}-ipam"
  operating_regions {
    region_name = data.aws_region.current.name
  }

  tags = merge(var.tags, {
    "region" = data.aws_region.current.name
  })
}

resource "aws_vpc_ipam_scope" "main" {
  ipam_id     = aws_vpc_ipam.main.id
  description = "${local.prefix}-${data.aws_region.current.name}-ipam-scope"
  tags = merge(var.tags, {
    "region" = data.aws_region.current.name
  })
}

# IPv4
resource "aws_vpc_ipam_pool" "main" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.main.private_default_scope_id
  locale         = data.aws_region.current.name
  tags = merge(var.tags, {
    "region" = data.aws_region.current.name
  })
}


resource "aws_vpc_ipam_pool_cidr" "main" {
  ipam_pool_id = aws_vpc_ipam_pool.main.id
  cidr         = var.vpc_cidr
}

resource "aws_vpc_ipam_preview_next_cidr" "main" {
  ipam_pool_id = aws_vpc_ipam_pool.main.id

  # a 18 netmask length is considered as too big for the CIDR pool
  netmask_length = 20
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.prefix}-vpc"
  cidr = aws_vpc_ipam_preview_next_cidr.main.cidr

  ipv4_ipam_pool_id = aws_vpc_ipam_pool.main.id

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # TODO(ameukam): Remove this after https://github.com/kubernetes/k8s.io/issues/5127 is closed
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  flow_log_cloudwatch_log_group_retention_in_days = 30

  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = merge(var.tags, {
    "region" = data.aws_region.current.name
  })
}
