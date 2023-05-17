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
  alias  = "eks-e2e-boskos-001"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[0]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

# Provider refering to eks-e2e-boskos-002 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-002"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[1]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

# Provider refering to eks-e2e-boskos-003 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-003"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[2]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

# Provider refering to eks-e2e-boskos-004 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-004"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[3]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

# Provider refering to eks-e2e-boskos-005 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-005"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[4]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

# Provider refering to eks-e2e-boskos-006 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-006"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[5]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

# Provider refering to eks-e2e-boskos-007 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-007"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[6]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

# Provider refering to eks-e2e-boskos-008 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-008"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[7]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

# Provider refering to eks-e2e-boskos-009 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-009"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[8]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

# Provider refering to eks-e2e-boskos-010 AWS account.
# "provisioner" user in eks-e2e-boskos-001 account has permission to assume
# the referenced role.
provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-010"

  assume_role {
    role_arn     = "arn:aws:iam::${var.boskos_accounts[9]}:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}
