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

# This script creates & configures the "real" serving repo in GCR,
# along with the prod GCS bucket.

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

# Grant access to "fake prod" projects for tol testing
# $1: The GCP project
# $2: The googlegroups group
function empower_group_to_fake_prod() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_to_fake_prod(project, group) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    group="$2"

    color 6 "Empowering $group as project viewer in $project"
    empower_group_as_viewer "${project}" "${group}"

    color 6 "Empowering $group for GCR in $project"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        empower_group_to_gcr "${project}" "${group}" "${r}"
    done
}

# The GCP project names.
PROD_PROJECT="k8s-artifacts-prod"
PROMOTER_TESTPROD_PROJECT="k8s-cip-test-prod"
PROMOTER_STAGING_PROJECT="k8s-staging-cip-test"
RELEASE_TESTPROD_PROJECT="k8s-release-test-prod"

ALL_PROD_PROJECTS=(
    "${PROD_PROJECT}"
    "${PROMOTER_TESTPROD_PROJECT}"
    "${RELEASE_TESTPROD_PROJECT}"
)

# Regions for prod.
PROD_REGIONS=(us eu asia)

# Make the projects, if needed
for prj in "${ALL_PROD_PROJECTS[@]}"; do
    color 6 "Ensuring project exists: ${prj}"
    ensure_project "${prj}"

    color 6 "Enabling the container registry API: ${prj}"
    enable_api "${prj}" containerregistry.googleapis.com

    color 6 "Enabling the container analysis API: ${prj}"
    enable_api "${prj}" containeranalysis.googleapis.com

    color 6 "Ensuring the GCR exists and is readable: ${prj}"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        ensure_gcr_repo "${prj}" "${r}"
    done

    color 6 "Empowering GCR admins: ${prj}"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        empower_gcr_admins "${prj}" "${r}"
    done

    color 6 "Empowering image promoter: ${prj}"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        empower_artifact_promoter "${prj}" "${r}"
    done

    color 6 "Enabling the GCS API: ${prj}"
    enable_api "${prj}" storage-component.googleapis.com

    color 6 "Ensuring the GCS bucket exists and is readable: ${prj}"
    ensure_gcs_bucket "${prj}" "gs://${prj}"

    color 6 "Empowering GCS admins: ${prj}"
    empower_gcs_admins "${prj}" "gs://${prj}"
done

# Special case: set the web policy on the prod bucket.
color 6 "Configuring the web policy on the bucket"
ensure_gcs_web_policy "gs://${PROD_PROJECT}"

# Special case: rsync static content into the prod bucket.
color 6 "Copying static content into bucket"
upload_gcs_static_content \
    "gs://${PROD_PROJECT}" \
    "${SCRIPT_DIR}/static/prod-storage"

# Special case: grant the image promoter testing group access to their fake
# prod project.
empower_group_to_fake_prod \
    "${PROMOTER_TESTPROD_PROJECT}" \
    "k8s-infra-staging-cip-test@kubernetes.io"

# Special case: grant the image promoter service account access to their
# staging, to allow e2e tests to run as that account, instead of yet a another.
empower_service_account_to_artifacts \
    $(svc_acct_email "${PROMOTER_TESTPROD_PROJECT}" "${PROMOTER_SVCACCT}") \
    "${PROMOTER_STAGING_PROJECT}"

# Special case: grant the release tools testing group access to their fake
# prod project.
empower_group_to_fake_prod \
    "${RELEASE_TESTPROD_PROJECT}" \
    "k8s-infra-staging-release-test@kubernetes.io"

# Special case: don't use retention on cip-test buckets
# (the retention appears to have been locked, so we set it to 1s instead)
gsutil retention set 1s gs://k8s-cip-test-prod

color 6 "Done"
