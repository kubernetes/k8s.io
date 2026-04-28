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

terraform {
  required_version = "~> 1.5.0"

  backend "s3" {
    # This S3 bucket is created in eks-e2e-boskos-001 AWS account
    bucket = "eks-e2e-boskos-tfstate"
    key    = "service-quotas/terraform.tfstate"
    region = "us-west-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.47"
    }
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-001 account.
module "capa_quotas_001" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-001
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-002 account.
module "capa_quotas_002" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-002
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-003 account.
module "capa_quotas_003" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-003
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-004 account.
module "capa_quotas_004" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-004
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-005 account.
module "capa_quotas_005" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-005
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-006 account.
module "capa_quotas_006" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-006
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-007 account.
module "capa_quotas_007" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-007
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-008 account.
module "capa_quotas_008" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-008
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-009 account.
module "capa_quotas_009" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-009
  }
}

# Module used to apply CAPA (Cluster API Provider AWS) quotas to eks-e2e-boskos-010 account.
module "capa_quotas_010" {
  source = "../modules/capa"

  providers = {
    aws = aws.eks-e2e-boskos-010
  }
}
