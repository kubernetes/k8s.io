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

# This script creates & configures the "real" serving repo in GCR.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0" > /dev/stderr
    echo > /dev/stderr
}

if [ $# != 0 ]; then
    usage
    exit 1
fi

# The GCP project names.
TEST_PROJECT="k8s-cip-test-prod"
PROD_PROJECT="k8s-gcr-prod"
TRASH_PROJECT="k8s-gcr-graveyard"

ALL_PROJECTS="${TEST_PROJECT} ${PROD_PROJECT} ${TRASH_PROJECT}"

# Regions for prod.
PROD_REGIONS=(us eu asia)

# Make the projects, if needed
for prj in ${ALL_PROJECTS}; do
    color 6 "Ensuring project exists: ${prj}"
    ensure_project "${prj}"

    color 6 "Configuring billing: ${prj}"
    ensure_billing "${prj}"

    color 6 "Enabling the container registry API: ${prj}"
    enable_api "${prj}" containerregistry.googleapis.com

    color 6 "Enabling the container analysis API for: ${prj}"
    enable_api "${prj}" containeranalysis.googleapis.com

    color 6 "Ensuring the registry exists and is readable: ${prj}"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        ensure_repo "${prj}" "${r}"
    done

    color 6 "Empowering GCR admins: ${prj}"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        empower_gcr_admins "${prj}" "${r}"
    done

    color 6 "Empowering image promoter: ${prj}"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        empower_promoter "${prj}" "${r}"
    done
done

# Special cases
color 6 "Empowering cip-test group in cip-test"
for r in "${PROD_REGIONS[@]}"; do
    color 3 "region $r"
    empower_group "${TEST_PROJECT}" "k8s-infra-gcr-staging-cip-test@googlegroups.com" "${r}"
done

color 6 "Done"
