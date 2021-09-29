#!/usr/bin/env bash

# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

terraform state mv 'module.boskos_janitor_sa.google_service_account.serviceaccount' 'module.workload_identity_service_accounts["boskos-janitor"].google_service_account.serviceaccount'
terraform state mv 'module.boskos_janitor_sa.google_service_account_iam_policy.serviceaccount_iam' 'module.workload_identity_service_accounts["boskos-janitor"].google_service_account_iam_policy.serviceaccount_iam'
terraform state mv 'module.kubernetes_external_secrets_sa.google_service_account.serviceaccount' 'module.workload_identity_service_accounts["kubernetes-external-secrets"].google_service_account.serviceaccount'
terraform state mv 'module.kubernetes_external_secrets_sa.google_service_account_iam_policy.serviceaccount_iam' 'module.workload_identity_service_accounts["kubernetes-external-secrets"].google_service_account_iam_policy.serviceaccount_iam'
terraform state mv 'module.prow_build_cluster_sa.google_service_account.serviceaccount' 'module.workload_identity_service_accounts["prow-build"].google_service_account.serviceaccount'
terraform state mv 'module.prow_build_cluster_sa.google_service_account_iam_policy.serviceaccount_iam' 'module.workload_identity_service_accounts["prow-build"].google_service_account_iam_policy.serviceaccount_iam'
