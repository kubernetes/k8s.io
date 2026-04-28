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

data "ibm_resource_group" "cos_group" {
  name = "k8s-infra"
}

resource "ibm_resource_instance" "cos_instance" {
  name              = "k8s-test-artifacts"
  resource_group_id = data.ibm_resource_group.cos_group.id
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
}

resource "ibm_cos_bucket" "cos_bucket" {
  lifecycle {
    ignore_changes = [
      region_location,
    ]
  }
  bucket_name           = "provider-ibm-cloud-test-infra"
  resource_instance_id  = ibm_resource_instance.cos_instance.id
  cross_region_location = "us"
  storage_class         = "smart"
}

resource "ibm_iam_authorization_policy" "policy" {
  source_service_name         = "secrets-manager"
  source_resource_instance_id = var.secrets_manager_id
  target_service_name         = "cloud-object-storage"
  target_resource_instance_id = ibm_resource_instance.cos_instance.guid
  roles                       = ["Key Manager"]
}

resource "ibm_sm_service_credentials_secret" "sm_service_credentials_secret" {
  instance_id = var.secrets_manager_id
  region      = "us-south"
  name        = "k8s-ppc-artifacts-svc-creds"
  rotation {
    auto_rotate = true
    interval    = 1
    unit        = "day"
  }
  source_service {
    instance {
      crn = ibm_resource_instance.cos_instance.crn
    }
    role {
      crn = "crn:v1:bluemix:public:iam::::serviceRole:Writer"
    }
    parameters = { "HMAC" : true }
  }
  ttl = "172800"
}
