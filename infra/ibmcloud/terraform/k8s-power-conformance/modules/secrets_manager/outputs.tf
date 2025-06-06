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

output "k8s_prow_secret_id" {
  value = ibm_sm_iam_credentials_secret.prow_secret.secret_id
}

output "k8s_janitor_secret_id" {
  value = ibm_sm_iam_credentials_secret.janitor_secret.secret_id
}

output "k8s_secret_rotator_id" {
  value = ibm_sm_iam_credentials_secret.secret_rotator.secret_id
}

output "k8s_prow_ssh_private_key_id" {
  value = ibm_sm_arbitrary_secret.ssh_private_key.secret_id
}

output "k8s_prow_ssh_public_key_id" {
  value = ibm_sm_arbitrary_secret.ssh_public_key.secret_id
}

output "k8s_prow_ssh_public_key" {
  value = tls_private_key.private_key.public_key_openssh
}
