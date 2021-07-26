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
set -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd )"

readonly project=kubernetes-public
readonly region=us-central1
readonly cluster=aaa
readonly context="gke_${project}_${region}_${cluster}"

function usage() {
    echo >&2 "Usage: $0"
    exit 1
}

function ensure_dependencies() {
    if ! command -v kubectl >/dev/null 2>&1; then
        echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/#kubectl"
        exit 1
    fi
}

function validate_kubernetes_resources() {
    gcloud \
        container clusters get-credentials \
        --project="${project}" \
        --region="${region}" \
        "${cluster}"

    kubectl \
        --context="${context}" \
        apply \
          --dry-run=server \
          --server-side=true \
          -f "${REPO_ROOT}/${@}" \
          --recursive
}


function main() {
    ensure_dependencies
    validate_kubernetes_resources "${@}"
}

if [ $# -gt 1 ]; then
    usage
fi

main "${@}"