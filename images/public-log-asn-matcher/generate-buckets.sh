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

#/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")"
SCRIPT_DIR="$(realpath "$(pwd)")"
GIT_ROOT="$(git rev-parse --show-toplevel)"

# ls -1 "${GIT_ROOT}"/audit/projects/*/buckets/ \
#     | grep -E '^k8s-artifacts|^k8s-staging|.*\.artifacts.k8s-artifacts-prod.appspot.com' \

cat "${SCRIPT_DIR}/buckets.txt" <(
    for B in "${GIT_ROOT}"/audit/projects/*/buckets/*; do
        BUCKET_NAME="$(basename "${B}")"
        if echo "${BUCKET_NAME}" \
            | grep -E '^k8s-artifacts|^k8s-staging|.*\.artifacts.k8s-artifacts-prod.appspot.com' \
            | grep -v '^.*-gcb$'; then
            echo "${BUCKET_NAME}"
        fi
    done
) \
    | sort \
    | uniq \
    | cat > "${SCRIPT_DIR}/buckets.txt.tmp"

mv "${SCRIPT_DIR}/buckets.txt.tmp" "${SCRIPT_DIR}/buckets.txt"
