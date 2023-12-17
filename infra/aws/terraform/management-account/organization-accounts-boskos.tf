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

module "k8s_infra_e2e_boskos_001" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-e2e-boskos-001"
  email                      = "k8s-infra-aws-admins+k8s-infra-e2e-boskos-001@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

}

module "k8s_infra_e2e_boskos_002" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-e2e-boskos-002"
  email                      = "k8s-infra-aws-admins+k8s-infra-e2e-boskos-002@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }
}

module "k8s_infra_e2e_boskos_003" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-e2e-boskos-003"
  email                      = "k8s-infra-aws-admins+k8s-infra-e2e-boskos-003@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

}

##############################################
# Accounts used by boskos in the EKS cluster #
##############################################

module "k8s_infra_eks_e2e_boskos_001" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-001"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-001@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}

module "k8s_infra_eks_e2e_boskos_002" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-002"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-002@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}

module "k8s_infra_eks_e2e_boskos_003" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-003"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-003@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}

module "k8s_infra_eks_e2e_boskos_004" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-004"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-004@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}

module "k8s_infra_eks_e2e_boskos_005" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-005"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-005@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}

module "k8s_infra_eks_e2e_boskos_006" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-006"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-006@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}

module "k8s_infra_eks_e2e_boskos_007" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-007"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-007@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}

module "k8s_infra_eks_e2e_boskos_008" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-008"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-008@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}

module "k8s_infra_eks_e2e_boskos_009" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-009"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-009@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}

module "k8s_infra_eks_e2e_boskos_010" {
  source = "../modules/org-account"

  account_name               = "k8s-infra-eks-e2e-boskos-010"
  email                      = "k8s-infra-aws-admins+k8s-infra-eks-e2e-boskos-010@kubernetes.io"
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "production"  = "true",
    "environment" = "prod",
    "group"       = "sig-k8s-infra",
    "service"     = "boskos"
  }
}


module "k8s_infra_e2e_boskos_scale_001" {
  source = "../modules/org-account"

  account_name = "k8s-infra-e2e-boskos-scale-001"
  email        = "k8s-infra-aws-boskos-accounts+scale-001@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "environment" = "prod",
    "group"       = "sig-scalability",
    "service"     = "boskos"
  }
}

module "k8s_infra_e2e_boskos_scale_002" {
  source = "../modules/org-account"

  account_name = "k8s-infra-e2e-boskos-scale-002"
  email        = "k8s-infra-aws-boskos-accounts+scale-002@kubernetes.io"
  parent_id    = aws_organizations_organizational_unit.boskos.id
  permissions_map = {
    "boskos-admin" = [
      "AdministratorAccess",
    ]
  }

  tags = {
    "environment" = "prod",
    "group"       = "sig-scalability",
    "service"     = "boskos"
  }
}
