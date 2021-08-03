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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd )"

function usage() {
    echo >&2 "Usage: $0"
    exit 1
}

function ensure_dependencies() {
    if ! command -v conftest >/dev/null 2>&1; then
        echo "Please install conftest: https://www.conftest.dev/install/"
        exit 1
    fi
}

function main() {
    ensure_dependencies

    pushd "${REPO_ROOT}" >/dev/null
    local k8s_yaml_paths=(
        apps
        infra/gcp/clusters/projects/*/*/resources
    )
    local conftest_flags=(
        # override the default of looking for $(pwd)/policy
        --policy "${REPO_ROOT}/policies/"
        # for some reason conftest tries to parse Makefiles as yaml
        --ignore Makefile
    )
    conftest test "${conftest_flags[@]}" "${k8s_yaml_paths[@]}"

}

if [ $# -gt 0 ]; then
    usage
fi

main
