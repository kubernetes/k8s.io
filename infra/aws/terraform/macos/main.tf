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


resource "aws_ec2_host" "mac" {
  count             = 1
  instance_type     = "mac2-m2.metal"
  availability_zone = "us-east-2c"
  host_recovery     = "on"
  auto_placement    = "on"
  tags = {
    Name = "mac-dedicated-host-${count.index + 1}"
  }
}

# Data source to get the latest macOS AMI
data "aws_ami" "macos" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ec2-macos-15.7*-arm64"] # macOS Sequoia
  }

  filter {
    name   = "architecture"
    values = ["arm64_mac"]
  }
}


// IAM
resource "aws_iam_role" "macos" {
  name = "macos-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachments_exclusive" "macos" {
  role_name = aws_iam_role.macos.name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]
}


resource "aws_iam_instance_profile" "macos" {
  name = "macos"
  role = aws_iam_role.macos.name
}

resource "aws_key_pair" "macos" {
  key_name   = "macos" # this is the same key as the aws-ssh key in prow
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnUSQbmHOztLhE7to3RhMElJeKWkEeK3va4sluwelJH8oHA8bQhGfleXYrIIvXFsZagpoggZ9b9Ed6JMcBOtI382o7yW8G9ZC7pxQVe+V2xYQAlDl5grdtgBVA3Cgy6ZtwLVATZhVnd7WIQh2FuvbR0I03PXO/dSWo2j8f/PInRdRTfubKTEWJV78OItYu6TCn+Fc5RABGlKRdWfhvkixmClOEATO+5o7q+p40VefQE84WLXApY8pCjCFL90SCCDqkgG9UFAdC/hSrvzs+Jk4N1Vhmj2c5jsZm0a9iWKTNKbohUlCnnatWvRY1WgbDiijJydXZzIliTInxZQeidZR7 zml"
}

resource "aws_instance" "mac_node" {
  count                = 1
  instance_type        = "mac2-m2.metal"
  key_name             = aws_key_pair.macos.key_name
  availability_zone    = "us-east-2c"
  iam_instance_profile = aws_iam_instance_profile.macos.name
  ami                  = data.aws_ami.macos.id
  tenancy              = "host"

  subnet_id                   = module.vpc.public_subnets[2]
  associate_public_ip_address = true
  user_data                   = <<-EOF
#!/bin/bash
brew install git make golang
EOF

  root_block_device {
    volume_size = 200
    volume_type = "gp3"
  }

  tags = {
    Name = "mac-1"
  }
}

