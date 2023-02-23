provider "azuread" {

}

terraform {
  #   backend "gcs" {
  #     bucket = "k8s-infra-tf-gcp"
  #     prefix = "azure-ad"
  #   }

  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }
  }
}
