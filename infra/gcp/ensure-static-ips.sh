#!/usr/bin/env bash
#
# Copyright 2020 The Kubernetes Authors.
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

# This script creates static ip addresses for services deployed in
# the `aaa` cluster

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

PROJECT_NAME="kubernetes-public"

function usage() {
    echo "usage: $0" > /dev/stderr
    echo > /dev/stderr
}

if [ $# != 0 ]; then
    usage
    exit 1
fi

ADDRESSES=(
    "gcsweb-k8s-io"
    "k8s-io-ingress-canary"
    "k8s-io-ingress-prod"
    "k8s-io-ingress-canary-v6"
    "k8s-io-ingress-prod-v6"
    "perf-dash-k8s-io-ingress-prod"
    "slack-infra-ingress-prod"
    "node-perf-dash-k8s-io-ingress-prod"
    "triage-party-release-ingress-prod"
)

for address in "${ADDRESSES[@]}"; do
    color 6 "Ensure address: $address"
    ensure_global_address "$PROJECT_NAME" "$address" "IP for aaa cluster Ingress"
done
