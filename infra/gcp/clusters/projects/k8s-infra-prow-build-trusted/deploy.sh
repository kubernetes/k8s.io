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

# intended to be run by k8s-infra-prow-build-trusted or a member of
# k8s-infra-oncall@kubernetes.io

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

readonly project=k8s-infra-prow-build-trusted
readonly region=us-central1
readonly cluster=prow-build-trusted
readonly context="gke_${project}_${region}_${cluster}"

function deploy_cluster_terraform() {
  pushd "${SCRIPT_ROOT}/${cluster}"
  terraform init
  terraform apply
  popd
}

function deploy_cluster_resources() {
    gcloud \
        container clusters get-credentials \
        --project="${project}" \
        --region="${region}" \
        "${cluster}"

    kubectl \
        --context="${context}" \
        apply \
          -f "${SCRIPT_ROOT}/${cluster}/resources" \
          --recursive
}

function main() {
  # TODO: deploy_cluster_terraform
  deploy_cluster_resources
}

main
