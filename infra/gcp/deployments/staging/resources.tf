module "project-artifact-promoter" {
  source       = "../tf_modules/project"
  project_name = "artifcat-promoter"
  project_id   = var.project_id
  env_name     = "staging"
  writer       = "k8s-infra-${env_name}-artifact-promoter@kubernetes.io"
  enable_api   = "containerregistry.googleapis.com"
  billing_account =  var.gcp_billing
}

module "build-image" {
  source       = "../tf_modules/project"
  project_name = "build-image"
  project_id   = var.project_id
  env_name     = "staging"
  writer       = "k8s-infra-${env_name}-build-image@kubernetes.io"
  enable_api   = "containerregistry.googleapis.com"
  billing_account =  var.gcp_billing
}

module "cip-test" {
  source       = "../tf_modules/project"
  project_name = "cip-test"
  project_id   = var.project_id
  env_name     = "staging"
  writers      = "k8s-infra-${env_name}-cip-test@kubernetes.io"
  enable_api   = "containerregistry.googleapis.com"
  billing_account =  var.gcp_billing
}