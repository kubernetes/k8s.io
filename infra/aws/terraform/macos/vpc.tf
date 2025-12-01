/*
Copyright 2025 The Kubernetes Authors.

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

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5"

  name = "macos-vpc"

  cidr = "10.1.0.0/16"

  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
  private_subnets = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.3.0/24", "10.1.4.0/24", "10.1.5.0/24"]

  # Enable public IPv4 addresses
  map_public_ip_on_launch = true

  # Enable IPv6
  enable_ipv6            = true
  create_egress_only_igw = true

  # Assign IPv6 address on creation to each instance
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_assign_ipv6_address_on_creation = true

  # Used for calculating IPv6 CIDR based on the following formula:
  # cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, var.private_subnet_ipv6_prefixes[count.index])
  private_subnet_ipv6_prefixes = [0, 1, 2]
  public_subnet_ipv6_prefixes  = [3, 4, 5]

  # NAT Gateway allows connection to external services (e.g. Internet).
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  default_security_group_ingress = [
    {
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = "0.0.0.0/0"
      ipv6_cidr_blocks = "::/0"
      description      = "Allow SSH from anywhere"
    }
  ]

  default_security_group_egress = [
    {
      from_port        = 0
      to_port          = 65535
      protocol         = "tcp"
      cidr_blocks      = "0.0.0.0/0"
      ipv6_cidr_blocks = "::/0"
      description      = "Allow all outbound traffic"
    }
  ]
}
