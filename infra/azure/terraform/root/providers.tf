/*
Copyright 2026 The Kubernetes Authors.

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
  required_version = "~> 1.11.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.57, < 5.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.8, < 3"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.7, < 4"
    }
  }

  backend "azurerm" {
    resource_group_name  = "k8s-infra-tf-states-rg"
    storage_account_name = "k8sinfratfstateprow"
    container_name       = "terraform-state"
    key                  = "root.terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "46678f10-4bbb-447e-98e8-d2829589f2d8" # Prod Subscription
  # Configuration options
  features {}
}

provider "azurerm" {
  subscription_id = "59cb4516-507c-4c86-bb40-6f3572dcfaeb" # CI Subscription
  alias           = "ci"
  # Configuration options
  features {}
}

provider "azapi" {
  subscription_id = "46678f10-4bbb-447e-98e8-d2829589f2d8"
}

provider "azuread" {
  # Configuration options
}

