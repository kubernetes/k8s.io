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

pip=pip3
pip_requirements="${REPO_ROOT}/requirements.txt"
yamllint_config="${SCRIPT_DIR}/.yamllint.conf"
yamllint_version=$(<"${pip_requirements}" grep yamllint | sed -e 's/.*==//')

function usage() {
    echo "usage: $0" > /dev/stderr
    echo "  verifies that yaml files in this repo pass 'yamllint -c ${yamllint_config}'"
    echo > /dev/stderr
}

if [ $# != 0 ]; then
    usage
    exit 1
fi

# we assume that pip3 is already installed
if ! command -v yamllint >/dev/null 2>&1; then
  echo "yamllint not found - installing with: ${pip} install -r ${pip_requirements}"
  ${pip} install -r ${pip_requirements}
fi

version=$(yamllint --version | awk '{ print $2 }')
if [[ "${version}" != "${yamllint_version}" ]]; then
  echo >/dev/stderr "ERROR: incorrect yamllint version '${version}' - please install with: ${pip} install ${pip_requirements}"
  exit 1
fi

cd "${REPO_ROOT}"
yamllint -c "${yamllint_config}" .
