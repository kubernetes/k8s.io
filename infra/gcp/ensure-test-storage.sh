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

# This script is used to create a new test service account for running container image promoter e2e tests.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0" > /dev/stderr
    echo > /dev/stderr
}

if [ $# != 0 ]; then
    usage
    exit 1
fi

# The service account name for the image promoter test account
PROMOTER_TEST_SVC="k8s-infra-gcr-promoter-test"

# GCP project names.
STAGING_PROJECT="k8s-staging-cip-test"
PROD_PROJECT="k8s-cip-test-prod"

ALL_PROJECTS=("${STAGING_PROJECT}" "${PROD_PROJECT}")

# GCR service account permissions
PERMISSIONS=("objectAdmin" "legacyBucketOwner")

# Empower image promoter
for prj in "${ALL_PROJECTS[@]}"; do
    color 6 "Empowering image promoter to GCR: ${prj}"
    for p in "${PERMISSIONS[@]}"; do
        color 6 "Granting permission: ${p}"
        empower_artifact_promoter "${PROMOTER_TEST_SVC}" "${prj}" "${p}"
    done
done