#!/usr/bin/env bash

# Copyright 2023 The Kubernetes Authors.
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

# This script creates deprecated buckets on a dedicated GCP project

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 [project...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all projects" > /dev/stderr
    echo "  $0 k8s-artifacts-prod # just do one" > /dev/stderr
    echo > /dev/stderr
}

# This is a list of all purgatory projects
mapfile -t PURGATORY_PROJECT < <(k8s_infra_projects "purgatory")
readonly PURGATORY_PROJECT

DEPRECATED_BUCKETS=(
    "artifacts.k8s-release.appspot.com"
    "k8s-release-asia"
    "k8s-release-dev-asia"
    "k8s-release-dev-eu"
    "k8s-release-eu"
)

readonly PROD_PROJECT_SERVICES=(
    # prod projects host unused GCS buckets
    storage-component.googleapis.com
)

function ensure_deprecated_buckets() {
    # Create deprecated GCS buckets.
    for bkt in "${DEPRECATED_BUCKETS[@]}"; do
        color 6 "Ensuring the GCS bucket: ${bkt}"
        ensure_private_gcs_bucket \
            "${PURGATORY_PROJECT}" \
            "gs://${bkt}" \
            | indent
    done
}

function main() {

    color 6 "Ensuring project exists: ${PURGATORY_PROJECT}"
    ensure_project "${PURGATORY_PROJECT[@]}"

    color 6 "Ensuring Services to host and analyze artifacts: ${PURGATORY_PROJECT}"
    ensure_services "${PURGATORY_PROJECT}" "${PROD_PROJECT_SERVICES[@]}" 2>&1 | indent

    color 6 "Ensuring deprecated buckets"
    ensure_deprecated_buckets 2>&1 | indent

    color 6 "Done"
}

main "${@}"
