terraform {
  required_version = "~> 0.13"
  backend "gcs" {
    bucket = "k8s-infra-clusters-terraform"
    prefix = "aws/accounts"
    # NOTE: Must specify encryption key
  }
}


# Terraform doesn't work well with count in modules (even in 0.13)

# Accounts for cluster-api-provider-aws project
module "capa-user-00" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-00"
  email       = "k8s-infra-aws-admins+capa2020111900@kubernetes.io"
  boskos-name = "capa-user-00"
}

module "capa-user-01" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-01"
  email       = "k8s-infra-aws-admins+capa2020111901@kubernetes.io"
  boskos-name = "capa-user-01"
}

module "capa-user-02" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-02"
  email       = "k8s-infra-aws-admins+capa2020111902@kubernetes.io"
  boskos-name = "capa-user-02"
}

module "capa-user-03" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-03"
  email       = "k8s-infra-aws-admins+capa2020111903@kubernetes.io"
  boskos-name = "capa-user-03"
}

module "capa-user-04" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-04"
  email       = "k8s-infra-aws-admins+capa2020111904@kubernetes.io"
  boskos-name = "capa-user-04"
}

module "capa-user-05" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-05"
  email       = "k8s-infra-aws-admins+capa2020111905@kubernetes.io"
  boskos-name = "capa-user-05"
}

module "capa-user-06" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-06"
  email       = "k8s-infra-aws-admins+capa2020111906@kubernetes.io"
  boskos-name = "capa-user-06"
}

module "capa-user-07" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-07"
  email       = "k8s-infra-aws-admins+capa2020111907@kubernetes.io"
  boskos-name = "capa-user-07"
}

module "capa-user-08" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-08"
  email       = "k8s-infra-aws-admins+capa2020111908@kubernetes.io"
  boskos-name = "capa-user-08"
}

module "capa-user-09" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-09"
  email       = "k8s-infra-aws-admins+capa2020111909@kubernetes.io"
  boskos-name = "capa-user-09"
}

module "capa-user-10" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-10"
  email       = "k8s-infra-aws-admins+capa2020111910@kubernetes.io"
  boskos-name = "capa-user-10"
}

module "capa-user-11" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-11"
  email       = "k8s-infra-aws-admins+capa2020111911@kubernetes.io"
  boskos-name = "capa-user-11"
}

module "capa-user-12" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-12"
  email       = "k8s-infra-aws-admins+capa2020111912@kubernetes.io"
  boskos-name = "capa-user-12"
}

module "capa-user-13" {
  source      = "./modules/account-and-user"
  id          = "capa-2020-11-19-13"
  email       = "k8s-infra-aws-admins+capa2020111913@kubernetes.io"
  boskos-name = "capa-user-13"
}


# Accounts for imagebuilder project
module "image-builder-aws-1" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-00"                    # TODO: Switch to -01
  email       = "k8s-infra-aws-admins+image2020111900@kubernetes.io" # TODO: Switch to 01
  boskos-name = "image-builder-aws-1"
}

module "image-builder-aws-2" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-02"
  email       = "k8s-infra-aws-admins+image2020111902@kubernetes.io"
  boskos-name = "image-builder-aws-2"
}

module "image-builder-aws-3" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-03"
  email       = "k8s-infra-aws-admins+image2020111903@kubernetes.io"
  boskos-name = "image-builder-aws-3"
}

module "image-builder-aws-4" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-04"
  email       = "k8s-infra-aws-admins+image2020111904@kubernetes.io"
  boskos-name = "image-builder-aws-4"
}

module "image-builder-aws-5" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-05"
  email       = "k8s-infra-aws-admins+image2020111905@kubernetes.io"
  boskos-name = "image-builder-aws-5"
}

module "image-builder-aws-6" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-06"
  email       = "k8s-infra-aws-admins+image2020111906@kubernetes.io"
  boskos-name = "image-builder-aws-6"
}

module "image-builder-aws-7" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-07"
  email       = "k8s-infra-aws-admins+image2020111907@kubernetes.io"
  boskos-name = "image-builder-aws-7"
}

module "image-builder-aws-8" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-08"
  email       = "k8s-infra-aws-admins+image2020111908@kubernetes.io"
  boskos-name = "image-builder-aws-8"
}

module "image-builder-aws-9" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-09"
  email       = "k8s-infra-aws-admins+image2020111909@kubernetes.io"
  boskos-name = "image-builder-aws-9"
}

module "image-builder-aws-10" {
  source      = "./modules/account-and-user"
  id          = "image-builder-aws-2020-11-19-10"
  email       = "k8s-infra-aws-admins+image2020111910@kubernetes.io"
  boskos-name = "image-builder-aws-10"
}
