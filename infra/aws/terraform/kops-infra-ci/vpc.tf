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

resource "aws_vpc_ipam" "main" {
  provider    = aws.kops-infra-ci
  description = "${local.prefix}-${data.aws_region.current.name}-ipam"
  operating_regions {
    region_name = data.aws_region.current.name
  }

  tags = merge(var.tags, {
    "region" = "${data.aws_region.current.name}"
  })
}

resource "aws_vpc_ipam_scope" "main" {
  provider    = aws.kops-infra-ci
  ipam_id     = aws_vpc_ipam.main.id
  description = "${local.prefix}-${data.aws_region.current.name}-ipam-scope"
  tags = merge(var.tags, {
    "region" = "${data.aws_region.current.name}"
  })
}

# IPv4
resource "aws_vpc_ipam_pool" "main" {
  provider       = aws.kops-infra-ci
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.main.private_default_scope_id
  locale         = data.aws_region.current.name
  tags = merge(var.tags, {
    "region" = "${data.aws_region.current.name}"
  })
}
