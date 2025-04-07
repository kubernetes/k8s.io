/*
Copyright 2025 The Kubernetes Authors.

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

resource "ibm_iam_service_id" "service_id" {
  name        = "sm-service-id"
  description = "Service id associated with secrets manager"
}

resource "ibm_iam_service_api_key" "service_id_apikey" {
  name           = "sm-read-apikey"
  iam_service_id = ibm_iam_service_id.service_id.iam_id
  store_value    = true
  locked         = true
}

resource "ibm_iam_service_policy" "policy_sm" {
  iam_service_id = ibm_iam_service_id.service_id.id
  roles          = ["SMRead"]

  resources {
    service           = "secrets-manager"
    resource_group_id = var.project_resource_group_id
  }
}

resource "ibm_iam_service_policy" "policy_iam_groups" {
  iam_service_id = ibm_iam_service_id.service_id.id
  roles          = ["Editor"]

  resources {
    service = "iam-groups"
  }
}

resource "ibm_iam_service_policy" "policy_iam_identity" {
  iam_service_id = ibm_iam_service_id.service_id.id
  roles          = ["Operator"]

  resources {
    service = "iam-identity"
  }
}
