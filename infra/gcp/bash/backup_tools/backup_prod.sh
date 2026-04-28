#!/usr/bin/env bash

# Copyright 2019 The Kubernetes Authors.
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

# USAGE NOTES
#
# Backs up prod registries. This is a thin orchestrator as all the heavy lifting
# is done by the gcrane binary.
#
# This script requires 1 environment variable to be defined:
#
# 1) GOPATH: toplevel path for checking out gcrane's source code.

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

SCRIPT_ROOT="$(dirname "$(readlink -f "$0")")"

export GCRANE_CHECKOUT_DIR="${GOPATH}/src/github.com/google/go-containerregistry"

# shellcheck disable=SC1090
source "${SCRIPT_ROOT}/backup_lib.sh"

# Backup GCRs for prod.
prod_repos=(
    asia.gcr.io/k8s-artifacts-prod
    eu.gcr.io/k8s-artifacts-prod
    us.gcr.io/k8s-artifacts-prod
)

# Sanity check
cred_sanity_check

# Build gcrane first.
build_gcrane

# Copy each region to its backup.
for repo in "${prod_repos[@]}"; do
    gcrane_copy "${repo}" "${repo}-bak"
done
