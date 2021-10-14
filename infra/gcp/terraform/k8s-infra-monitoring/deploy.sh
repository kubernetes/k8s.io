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

readonly project=kubernetes-public
readonly region=us-central1

function deploy_terraform() {
  pushd "${SCRIPT_ROOT}"
  terraform init
  terraform apply -auto-approve
  popd
}

function main() {
    echo "deploying resources in project ${project} and region ${region}"
    deploy_terraform
}

main
