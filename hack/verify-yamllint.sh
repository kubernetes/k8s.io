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

pip=pip3
pip_requirements="${SCRIPT_DIR}/requirements.txt"
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

if ! which yamllint >/dev/null 2>&1; then
  echo >&2 "ERROR: yamllint not found - please install with: ${pip} install -r ${pip_requirements}"
  exit 1
fi

version=$(yamllint --version | awk '{ print $2 }')
if [[ "${version}" != "${yamllint_version}" ]]; then
  echo >&2 "ERROR: incorrect yamllint version '${version}' - please install with: ${pip} install ${pip_requirements}"
  exit 1
fi

cd ${SCRIPT_DIR}/..

yamllint -c "${yamllint_config}" .
