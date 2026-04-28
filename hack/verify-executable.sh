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

# verifies that all expected files are executable, excluding special cases

set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly REPO_ROOT

# files that SHOULD be executable
readonly exec_regexes=(
    .*\.sh # *.sh
    .*\.py # *.py
)
# files that should NOT be executable (exceptions to the regexes above)
readonly noexec_regexes=(
    .*/lib.*\.sh # lib_foo.sh should be sourced by other scripts, not executed
)

# convert arrays to extended regexes
exec_regex="^($(IFS='|'; echo "${exec_regexes[*]}"))$"
noexec_regex="^($(IFS='|'; echo "${noexec_regexes[*]}"))$"
readonly exec_regex noexec_regex

# get the list of files, names are relative to REPO_ROOT
mapfile -t files < <(
    find "${REPO_ROOT}" -type f \
      -print \
    | sort \
    | grep -E "${exec_regex}" \
    | sed -e "s|${REPO_ROOT}/||"
)
readonly files

# for each file, verify whether it's executable, and whether that's expected
failures=()
for file in "${files[@]}"; do
    # Ignore anything that git would. We don't do this via find -exec above
    # because it's slow and there are too many files; now that we've pruned
    # the file list with grep
    if git check-ignore -q "${file}"; then
        continue
    fi
    echo "# checking ${file}"
    actual=false
    if [ -x "${REPO_ROOT}/${file}" ]; then
        actual=true
    fi
    expected=true
    should="SHOULD"
    if echo "${file}" | grep -qE "${noexec_regex}"; then
        expected=false
        should="should NOT"
    fi
    # since bash doesn't have logical xor...
    if [ "${expected}" != "${actual}" ]; then
        failures+=("${file} ${should} be executable")
    fi
done 

# determine pass/fail
result="passed"
code=0
if [ ${#failures[@]} != 0 ]; then
    result="failed"
    code=1
fi

# report (parseable as yaml)
echo "result: ${result}"
echo "failures:"
printf "%s\n" "${failures[@]/#/- }"
exit "${code}"
