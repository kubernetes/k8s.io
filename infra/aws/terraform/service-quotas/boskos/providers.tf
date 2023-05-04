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

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-001"

  assume_role {
    role_arn     = "arn:aws:iam::995654820765:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-002"

  assume_role {
    role_arn     = "arn:aws:iam::252228595925:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-003"

  assume_role {
    role_arn     = "arn:aws:iam::757254795865:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-004"

  assume_role {
    role_arn     = "arn:aws:iam::236737742629:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-005"

  assume_role {
    role_arn     = "arn:aws:iam::568640253687:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-006"

  assume_role {
    role_arn     = "arn:aws:iam::325389058785:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-007"

  assume_role {
    role_arn     = "arn:aws:iam::819381709038:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-008"

  assume_role {
    role_arn     = "arn:aws:iam::080553712153:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-009"

  assume_role {
    role_arn     = "arn:aws:iam::187041256112:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}

provider "aws" {
  region = var.region
  alias  = "eks-e2e-boskos-010"

  assume_role {
    role_arn     = "arn:aws:iam::502839862640:role/Provisioner"
    session_name = "service-quotas-boskos-tf"
  }
}
