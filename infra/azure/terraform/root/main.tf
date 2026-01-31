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
// Azure RBAC

module "role_assignments" {
  source = "github.com/Azure/terraform-azurerm-avm-res-authorization-roleassignment?ref=v0.3.0"
  #   version = "0.3.0"
  groups_by_display_name = {
    capz-admins = "capz-admins"
    owners      = "owners"
  }
  app_registrations_by_display_name = {
    datadog   = "Datadog"
    terraform = "Terraform"
  }
  #   user_assigned_managed_identities_by_display_name = {}
  role_definitions = {
    owner = {
      name = "Owner"
    }
    contributor = {
      name = "Contributor"
    }
    reader = {
      name = "Reader"
    }
    monitoring-reader = {
      name = "Monitoring Reader"
    }
  }

  entra_id_role_definitions = {
    application-administrator = {
      display_name = "Application Administrator"
    }
  }

  role_assignments_for_management_groups = {
    root = {
      management_group_display_name = "Tenant Root Group"
      role_assignments = {
        owner = {
          role_definition = "owner"
          any_principals  = ["owners", "terraform"]
        }
        monitoring-reader = {
          role_definition   = "monitoring-reader"
          app_registrations = ["datadog"]
        }
      }
    }
  }

  role_assignments_for_subscriptions = {
    prod = {
      subscription_id = local.subscriptions_id["prod"]
      role_assignments = {
        owner = {
          role_definition = "owner"
          groups          = ["capz-admins"]
        }
      }

    }
    ci = {
      subscription_id = local.subscriptions_id["ci"]
      role_assignments = {
        owner = {
          role_definition = "owner"
          groups          = ["capz-admins"]
        }
      }
    }
  }

}
