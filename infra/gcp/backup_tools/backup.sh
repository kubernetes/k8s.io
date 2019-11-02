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
# is done by the gcrane binary. The only required argument is the path to the
# service account that has write access to the backup GCRs.

set -o errexit
set -o nounset
set -o pipefail

copy_with_date()
{
    local gcrane_img
    local gcrane_digest
    local timestamp
    local source_gcr_repo
    local backup_gcr_repo
    local sa_key_path

    # The image is pinned to an exact sha256 version because the gcrane binary's
    # behavior must never change (otherwise, the "docker run" invocation below
    # might explode unexpectedly).
    gcrane_digest="560757a7b63c85e9b95d2d971a18aa2a2425899e36f1550ce3584018d9ac49ea" # version 7683b4ee5f6150cb47a791309f781c522b95a58f
    gcrane_img="gcr.io/go-containerregistry/gcrane@sha256:${gcrane_digest}"

    # We use a timestamp of the form YYYY/MM/DD/HH because this makes the backup
    # folders more easily traversable from a human perspective.
    timestamp="$(date -u +"%Y/%m/%d/%H")"

    if (( $# != 3 )); then
        cat << EOF >&2
copy_with_date: usage <source_gcr_repo> <backup_gcr_repo> <sa_key_path>
e.g. copy_with_date "us.gcr.io/k8s-artifacts-prod" "us.gcr.io/k8s-artifacts-prod-bak" /path/to/sa/key.json
EOF
        exit 1
    fi

    source_gcr_repo="${1}" # "us.gcr.io/k8s-artifacts-prod"
    backup_gcr_repo="${2}" # "us.gcr.io/k8s-artifacts-prod-bak"
    sa_key_path="${3}"

    # Perform backup by copying all images recursively over.
    docker run \
        -v "${sa_key_path}":/auth.json \
        --env GOOGLE_APPLICATION_CREDENTIALS=/auth.json \
        "${gcrane_img}" \
            cp -r "${source_gcr_repo}" "${backup_gcr_repo}/${timestamp}"
}

if (( $# != 1 )); then
    "usage: ./backup.sh <svc_acct_key_path_for_backup_gcr>"
    exit 1
fi

prod_repos=(
    asia.gcr.io/k8s-artifacts-prod
    eu.gcr.io/k8s-artifacts-prod
    us.gcr.io/k8s-artifacts-prod
)
sa_key_path="${1}"

# Copy each region to its backup.
for prod_repo in "${prod_repos[@]}"; do
    copy_with_date "${prod_repo}" "${prod_repo}-bak" "${sa_key_path}"
done
