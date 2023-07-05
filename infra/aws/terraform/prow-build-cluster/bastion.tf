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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] // Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "eks_nodes" {
  key_name_prefix = "${var.cluster_name}-nodes"
  public_key      = var.public_key
}

resource "aws_instance" "bastion" {
  count = var.bastion_install ? 1 : 0

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.nano"
  subnet_id                   = module.vpc.public_subnets[0]
  key_name                    = aws_key_pair.eks_nodes.key_name
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.bastion_host_security_group[0].id
  ]

  tags = {
    Name = "${var.cluster_name}-bastion"
  }
}

resource "aws_security_group" "bastion_host_security_group" {
  count = var.bastion_install ? 1 : 0

  name        = "eks-nodes-bastion"
  description = "Enable SSH access to the bastion host from external via SSH port"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "SSH to Bastion"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "bastion_ip_address" {
  value = var.bastion_install ? aws_instance.bastion[0].public_ip : null
}
