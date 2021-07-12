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

# runs shellcheck for all *.sh files in this repo, assuming a bash dialect

set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly REPO_ROOT

readonly TMPDIR="${TMPDIR:-${REPO_ROOT}/tmp}"
readonly SHELLCHECK_OUTPUT="${TMPDIR}/shellcheck.txt"
mkdir -p "$(dirname "${SHELLCHECK_OUTPUT}")"
echo -n '' > "${SHELLCHECK_OUTPUT}"

mapfile -t files < <(
    find "${REPO_ROOT}" -type f -name '*.sh' | sort
)
readonly files

readonly shellcheck_cmd=(
    shellcheck
    --shell=bash
    --external-sources
    --source-path=SCRIPTDIR
)

failed_files=()
passed_files=()
# calling shellcheck for each file takes longer, but:
# - allows --source-path to work for adjacent files
# - allows listing which specific files failed at end
for file in "${files[@]}"; do
    echo "# checking ${file#${REPO_ROOT}\/}"
    if ! "${shellcheck_cmd[@]}" "${file}" >>"${SHELLCHECK_OUTPUT}" 2>&1; then
        failed_files+=("${file}")
    else
        passed_files+=("${file}")
    fi
done

result="passed"
code=0
if [ ${#failed_files[@]} != 0 ]; then
    result="failed"
    code=1
fi

echo "result: ${result}"
echo "shellcheck_cmd: ${shellcheck_cmd[*]} {file}"
echo "shellcheck_output: >"
<"${SHELLCHECK_OUTPUT}" sed -e 's/^/  /'
# echo "passing_files:"
# printf "%s\n" "${passed_files[@]/#${REPO_ROOT}\//- }"
echo "failing_files:"
printf "%s\n" "${failed_files[@]/#${REPO_ROOT}\//- }"
exit "${code}"
