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

provider "aws" {
  region = var.region
}

# Provider refering to eks-e2e-boskos-001 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "boskos-scale-001"
  default_tags {
    tags = {
      Environment = "Production"
      Shared      = "Ignore"
    }
  }
  assume_role {
    role_arn = "arn:aws:iam::${lookup(local.accounts, "boskos-scale-001")}:role/OrganizationAccountAccessRole"
  }
}

