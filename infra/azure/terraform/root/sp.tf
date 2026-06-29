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

locals {
  apps = toset([
    "Terraform",
    "rg-cleanup",
    "prow"
  ])
  build_cluster_issuers = {
    aks = {
      issuer = "https://eastus2.oic.prod-aks.azure.com/d1aa7522-0959-442e-80ee-8c4f7fb4c184/85d5aa19-bc3c-4cdb-bc17-0cf8703cfa3f"
    }
    eks = {
      issuer = "https://oidc.eks.us-east-2.amazonaws.com/id/F8B73554FE6FBAF9B19569183FB39762"
    }
    gke = {
      issuer = "https://container.googleapis.com/v1/projects/k8s-infra-prow-build/locations/us-central1/clusters/prow-build"
    }
  }
  graph_api_permissions = {
    Terraform = {
      roles = [
        "62a82d76-70ea-41e2-9197-370581804d09", # Group.ReadWrite.All
        "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9", # Application.ReadWrite.All
        "df021288-bdef-4463-88db-98f22de89214", # User.Read.All
        "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8", # RoleManagement.ReadWrite.Directory
      ]
    }
  }

}

resource "azuread_application" "apps" {
  for_each     = local.apps
  display_name = each.key

  dynamic "required_resource_access" {
    for_each = try(local.graph_api_permissions[each.key], null) == null ? [] : [local.graph_api_permissions[each.key]]
    content {
      resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

      dynamic "resource_access" {
        for_each = required_resource_access.value.roles
        content {
          id   = resource_access.value
          type = "Role"
        }
      }
    }
  }
}

resource "azuread_service_principal" "service_principals" {
  for_each  = local.apps
  client_id = azuread_application.apps[each.key].client_id
}

resource "azuread_application_federated_identity_credential" "terraform" {
  for_each = toset([
    "system:serviceaccount:atlantis:atlantis",
  ])
  display_name   = reverse(split(":", each.key))[0]
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://container.googleapis.com/v1/projects/k8s-infra-prow/locations/us-central1/clusters/utility"
  application_id = azuread_application.apps["Terraform"].id
  subject        = each.key
}

resource "azuread_application_federated_identity_credential" "rg_cleanup" {
  for_each = toset([
    "system:serviceaccount:test-pods:rg-cleanup",
  ])
  display_name   = reverse(split(":", each.key))[0]
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://eastus2.oic.prod-aks.azure.com/d1aa7522-0959-442e-80ee-8c4f7fb4c184/85d5aa19-bc3c-4cdb-bc17-0cf8703cfa3f"
  application_id = azuread_application.apps["rg-cleanup"].id
  subject        = each.key
}

resource "azuread_application_federated_identity_credential" "prow" {
  for_each       = local.build_cluster_issuers
  display_name   = each.key
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = each.value.issuer
  application_id = azuread_application.apps["prow"].id
  subject        = "system:serviceaccount:test-pods:azure"
}
