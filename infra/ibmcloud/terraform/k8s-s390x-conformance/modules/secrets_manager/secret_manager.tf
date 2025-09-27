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
locals {
  secrets_manager_region = "eu-de"
}

resource "ibm_sm_iam_credentials_configuration" "sm_iam_credentials_configuration_instance" {
  instance_id = var.secrets_manager_id
  region      = local.secrets_manager_region
  name        = "iam_config"
  api_key     = var.apikey
}
resource "ibm_sm_iam_credentials_secret" "prow_secret" {
  depends_on    = [ibm_sm_iam_credentials_configuration.sm_iam_credentials_configuration_instance]
  instance_id   = var.secrets_manager_id
  description   = "API key used for running the Prow job on the s390x platform."
  region        = local.secrets_manager_region
  name          = "prow-job-api-key"
  access_groups = [var.vpc_build_cluster_access_group_id]
  labels        = ["rotate:true"]

  //The time-to-live (TTL) or lease duration of generated secret 14400seconds = 4hrs
  ttl = "14400"
}
resource "ibm_sm_iam_credentials_secret" "janitor_secret" {
  depends_on    = [ibm_sm_iam_credentials_configuration.sm_iam_credentials_configuration_instance]
  instance_id   = var.secrets_manager_id
  description   = "API key used by Boskos deployment ibmcloud-janitor."
  region        = local.secrets_manager_region
  name          = "boskos-janitor-api-key"
  labels        = ["rotate:true"]
  access_groups = [var.janitor_access_group_id]

  //The time-to-live (TTL) or lease duration of generated secret 14400seconds = 4hrs
  ttl = "14400"
}

resource "ibm_sm_iam_credentials_secret" "secret_rotator" {
  depends_on    = [ibm_sm_iam_credentials_configuration.sm_iam_credentials_configuration_instance]
  instance_id   = var.secrets_manager_id
  description   = "API key used by secret-manager(rotator)."
  region        = local.secrets_manager_region
  name          = "secret-rotator-api-key"
  access_groups = [var.secret_rotator_access_group_id]

  //Auto rotate secret after 1day = 24hrs, the minimum value is 1
  rotation {
    auto_rotate = true
    interval    = 1
    unit        = "day"
  }

  //The time-to-live (TTL) or lease duration of generated secret 86400seconds = 24hrs
  ttl = "86400"
}

# RSA key of size 4096 bits
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "ibm_sm_arbitrary_secret" "ssh_private_key" {
  name        = "prow-job-ssh-private-key"
  description = "Private SSH key used for authenticating and securely connecting to servers or systems during the execution of Prow jobs."
  instance_id = var.secrets_manager_id
  region      = local.secrets_manager_region
  labels      = ["prow-job-ssh-private-key"]
  payload     = tls_private_key.private_key.private_key_openssh
}

resource "ibm_sm_arbitrary_secret" "ssh_public_key" {
  name        = "prow-job-ssh-public-key"
  description = "Public SSH key used for securely authenticating Prow jobs by allowing access to servers or systems during job execution."
  instance_id = var.secrets_manager_id
  region      = local.secrets_manager_region
  labels      = ["prow-job-ssh-public-key"]
  payload     = tls_private_key.private_key.public_key_openssh
}
