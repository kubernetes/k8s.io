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

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)

function usage() {
    echo >&2 "Usage: $0 [path...]"
    exit 1
}

function ensure_dependencies() {
    if [ -z "$(which curl)" ]; then
        echo "Please install curl"
        exit 1
    fi

    if [ -z "$(which tfswitch)" ]; then
        echo "Please install tfswitch"
        exit 1
    fi
}

function check_terraform() {
  local path="${1}"

  if [ ! -d "${path}" ]; then
      echo "check_terraform: path '${path}' is not a directory (or does not exist)"
      return 1
  fi

  pushd "${path}" >/dev/null

  echo "# Installing terraform for path: ${path} ..."
  tfswitch

  echo "# Running terraform validate for path: ${path} ..."
  terraform init -backend=false
  terraform validate

  popd >/dev/null
}

function main() {
    local paths=("$@")
    local failures=()

    ensure_dependencies

    # if no paths specified, default to all paths that contain *.tf,
    # excluding modules/* since those are picked up by way of inclusion
    # in the rest of our terraform
    pushd "$REPO_ROOT"
    if [ "${#paths[@]}" == 0 ]; then
        mapfile -t paths < <(
          find . -name '*.tf' -print0 \
            | xargs -0 -n1 dirname \
            | sort \
            | uniq \
            | grep -v ^./infra/gcp/terraform/modules/
        )
    fi

    # verify all terraform paths
    for path in "${paths[@]}"; do
        echo "# Verifying terraform for path: ${path} ..."
        if ! check_terraform "${path}"; then
            failures+=("${path}")
        fi
    done

    # determine pass/fail
    result="passed"
    code=0
    if [ ${#failures[@]} != 0 ]; then
        result="failed"
        code=1
    fi

    # report
    echo "result: ${result}"
    echo "failures:"
    printf "%s\n" "${failures[@]/#/- }"
    exit "${code}"
}

main "$@"
