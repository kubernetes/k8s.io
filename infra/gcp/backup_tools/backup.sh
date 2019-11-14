#!/usr/bin/env bash
#
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
# This script requires 3 environment variables to be defined:
#
# 1) GOPATH: toplevel path for checking out gcrane's source code.
#
# 2) GCRANE_REF: the commit SHA to use for building the gcrane binary.
#
# 3) GOOGLE_APPLICATION_CREDENTIALS: path to the service account (JSON file)
# that has write access to the backup GCRs.

set -o errexit
set -o nounset
set -o pipefail

GCRANE_CHECKOUT_DIR="${GOPATH}/src/github.com/google/go-containerregistry"

build_gcrane()
{
    git clone https://github.com/google/go-containerregistry "${GCRANE_CHECKOUT_DIR}"
    pushd "${GCRANE_CHECKOUT_DIR}/cmd/gcrane"
    git reset --hard "${GCRANE_REF}"
    # Build offline from vendored sources.
    go build -mod=vendor
    popd
}

copy_with_date()
{
    local timestamp
    local source_gcr_repo
    local backup_gcr_repo

    # We use a timestamp of the form YYYY/MM/DD/HH because this makes the backup
    # folders more easily traversable from a human perspective.
    timestamp="$(date -u +"%Y/%m/%d/%H")"

    if (( $# != 2 )); then
        cat << EOF >&2
copy_with_date: usage <source_gcr_repo> <backup_gcr_repo>
e.g. copy_with_date "us.gcr.io/k8s-artifacts-prod" "us.gcr.io/k8s-artifacts-prod-bak"
EOF
        exit 1
    fi

    source_gcr_repo="${1}" # "us.gcr.io/k8s-artifacts-prod"
    backup_gcr_repo="${2}" # "us.gcr.io/k8s-artifacts-prod-bak"

    # Perform backup by copying all images recursively over.
    "${GCRANE_CHECKOUT_DIR}/cmd/gcrane/gcrane" cp -r "${source_gcr_repo}" "${backup_gcr_repo}/${timestamp}"
}

prod_repos=(
    asia.gcr.io/k8s-artifacts-prod
    eu.gcr.io/k8s-artifacts-prod
    us.gcr.io/k8s-artifacts-prod
)

# Build gcrane first.
build_gcrane

# Copy each region to its backup.
for prod_repo in "${prod_repos[@]}"; do
    copy_with_date "${prod_repo}" "${prod_repo}-bak"
done
