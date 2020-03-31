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
        empower_group_to_write_gcr "${group}" "${project}" "${r}"
    done
}

#
# The GCP project names.
#

# This is the "real" prod project for artifacts serving and backups.
PROD_PROJECT="k8s-artifacts-prod"
PRODBAK_PROJECT="${PROD_PROJECT}-bak"

# These are for testing the image promoter's promotion process.
PROMOTER_TEST_PROD_PROJECT="k8s-cip-test-prod"
PROMOTER_TEST_STAGING_PROJECT="k8s-staging-cip-test"

# These are for testing the GCR backup/restore process.
GCR_BACKUP_TEST_PROD_PROJECT="k8s-gcr-backup-test-prod"
GCR_BACKUP_TEST_PRODBAK_PROJECT="${GCR_BACKUP_TEST_PROD_PROJECT}-bak"

# This is for testing the GCR auditing mechanism.
GCR_AUDIT_TEST_PROD_PROJECT="k8s-gcr-audit-test-prod"

# This is for testing the release tools.
RELEASE_TESTPROD_PROJECT="k8s-release-test-prod"
RELEASE_STAGING_CLOUDBUILD_ACCOUNT="615281671549@cloudbuild.gserviceaccount.com"

ALL_PROD_PROJECTS=(
    "${PROD_PROJECT}"
    "${PRODBAK_PROJECT}"
    "${PROMOTER_TEST_PROD_PROJECT}"
    "${GCR_BACKUP_TEST_PROD_PROJECT}"
    "${GCR_BACKUP_TEST_PRODBAK_PROJECT}"
    "${GCR_AUDIT_TEST_PROD_PROJECT}"
    "${RELEASE_TESTPROD_PROJECT}"
)

# Regions for prod.
PROD_REGIONS=(us eu asia)

# Minimum time we expect to keep prod artifacts.
PROD_RETENTION="10y"

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
    ensure_public_gcs_bucket "${prj}" "gs://${prj}"

    color 6 "Ensuring the GCS bucket retention policy is set: ${prj}"
    ensure_gcs_bucket_retention "gs://${prj}" "${PROD_RETENTION}"

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

# Special case: grant the push groups access to their buckets.
# This is for serving CNI artifacts.  We need a new bucket for this because
# there's no concept of permissions on a "subdirectory" of a bucket.  So until we
# have a promoter for k8s-artifacts-prod, we do this.
CNI_BUCKET="k8s-artifacts-cni"
CNI_GROUP="k8s-infra-push-cni@kubernetes.io"
color 6 "Ensuring the CNI GCS bucket exists and is readable"
ensure_public_gcs_bucket "${PROD_PROJECT}" "gs://${CNI_BUCKET}"
color 6 "Ensuring the CNI GCS bucket retention policy is set"
ensure_gcs_bucket_retention "gs://${CNI_BUCKET}" "${PROD_RETENTION}"
color 6 "Empowering GCS admins to CNI"
empower_gcs_admins "${PROD_PROJECT}" "gs://${CNI_BUCKET}"
empower_group_to_write_gcs_bucket "${CNI_GROUP}" "gs://${CNI_BUCKET}"

# Special case: grant the image promoter testing group access to their fake
# prod projects.
empower_group_to_fake_prod \
    "${PROMOTER_TEST_PROD_PROJECT}" \
    "k8s-infra-staging-cip-test@kubernetes.io"
empower_group_to_fake_prod \
    "${PROMOTER_TEST_STAGING_PROJECT}" \
    "k8s-infra-staging-cip-test@kubernetes.io"
empower_group_to_fake_prod \
    "${GCR_BACKUP_TEST_PROD_PROJECT}" \
    "k8s-infra-staging-cip-test@kubernetes.io"
empower_group_to_fake_prod \
    "${GCR_BACKUP_TEST_PRODBAK_PROJECT}" \
    "k8s-infra-staging-cip-test@kubernetes.io"
empower_group_to_fake_prod \
    "${GCR_AUDIT_TEST_PROD_PROJECT}" \
    "k8s-infra-staging-cip-test@kubernetes.io"

# Special case: grant the image promoter test service account access to their
# staging, to allow e2e tests to run as that account, instead of yet another.
empower_svcacct_to_admin_gcr \
    $(svc_acct_email "${PROMOTER_TEST_PROD_PROJECT}" "${PROMOTER_SVCACCT}") \
    "${PROMOTER_TEST_STAGING_PROJECT}"

# Special case: grant the image promoter test service account access to
# their testing project (used for running e2e tests for the promoter auditing
# mechanism).
empower_service_account_for_cip_auditor_e2e_tester \
    $(svc_acct_email "${GCR_AUDIT_TEST_PROD_PROJECT}" "${PROMOTER_SVCACCT}") \
    "${GCR_AUDIT_TEST_PROD_PROJECT}"

# Special case: grant the GCR backup-test svcacct access to the "backup-test
# prod" project (which models the real $PROD_PROJECT) so it can write the
# source images and then execute tests of the backup system.  This svcacct
# already has access to the "backup-test prod backup" project (which models the
# real $PRODBAK_PROJECT).  We don't want this same power for the non-test
# backup system, so a compromised promoter can't nuke backups.
empower_svcacct_to_write_gcr \
    $(svc_acct_email "${GCR_BACKUP_TEST_PRODBAK_PROJECT}" "${PROMOTER_SVCACCT}") \
    "${GCR_BACKUP_TEST_PROD_PROJECT}"

# Special case: grant the Release Managers group access to their fake
# prod project.
empower_group_to_fake_prod \
    "${RELEASE_TESTPROD_PROJECT}" \
    "k8s-infra-staging-kubernetes@kubernetes.io"

empower_group_to_fake_prod \
    "${RELEASE_TESTPROD_PROJECT}" \
    "k8s-infra-staging-release-test@kubernetes.io"

# Special case: grant the k8s-staging-kubernetes Cloud Build account access to
# write to the primary test prod GCS bucket. This currently is a requirement
# for anago.
empower_svcacct_to_write_gcs_bucket \
    "${RELEASE_STAGING_CLOUDBUILD_ACCOUNT}" \
    "gs://${RELEASE_TESTPROD_PROJECT}"

# Special case: don't use retention on cip-test buckets
gsutil retention clear gs://k8s-cip-test-prod

# Special case: give Cloud Run Admin privileges to the group that will
# administer the cip-auditor (so that they can deploy the auditor to Cloud Run).
empower_group_to_admin_artifact_auditor \
    "${PROD_PROJECT}" \
    "k8s-infra-artifact-admins@kubernetes.io"
# Special case: create/add-permissions for necessary service accounts for the auditor.
empower_artifact_auditor "${PROD_PROJECT}"
empower_artifact_auditor_invoker "${PROD_PROJECT}"

# Special case: empower Kubernetes service account to authenticate as a GCP
# service account.
empower_ksa_to_svcacct \
    "k8s-prow.svc.id.goog[test-pods/k8s-infra-gcr-promoter]" \
    "${PROD_PROJECT}" \
    $(svc_acct_email "${PROD_PROJECT}" "${PROMOTER_SVCACCT}")

color 6 "Done"
