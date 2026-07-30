#!/usr/bin/env bash
# Copyright 2026 The Kubernetes Authors.
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

# verifies that kubernetes/gke-prow-build-trusted/prow/builds-sa.yaml is in sync
# with local.registries in infra/gcp/terraform/k8s-staging-images/registries.tf

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function usage() {
    echo "usage: $0" > /dev/stderr
    echo "  verifies that the generated prow build service accounts are up to date" > /dev/stderr
    echo > /dev/stderr
}

if [ $# != 0 ]; then
    usage
    exit 1
fi

"${SCRIPT_DIR}/generate-staging-builds-sa.sh" --verify
