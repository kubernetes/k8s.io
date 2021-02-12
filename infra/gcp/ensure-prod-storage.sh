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

PROW_UNTRUSTED_BUILD_CLUSTER_PROJECTS=(
    "k8s-prow-builds"
    "k8s-infra-prow-build"
)

PROW_TRUSTED_BUILD_CLUSTER_PROJECTS=(
    "k8s-prow"
    "k8s-infra-prow-build-trusted"
)

# This is a list of all prod projects.  Each project will be configured
# similarly, with a GCR repository and a GCS bucket of the same name.
#
ALL_PROD_PROJECTS=(
    "${PROD_PROJECT}"
    "${PRODBAK_PROJECT}"
    "${PROMOTER_TEST_PROD_PROJECT}"
    "${GCR_BACKUP_TEST_PROD_PROJECT}"
    "${GCR_BACKUP_TEST_PRODBAK_PROJECT}"
    "${GCR_AUDIT_TEST_PROD_PROJECT}"
    "${RELEASE_TESTPROD_PROJECT}"
)

# This is a list of all prod GCS buckets, but only their trailing "name".  Each
# name will get a GCS bucket called "k8s-artifacts-${name}", and write access
# will be granted to the group "k8s-infra-push-${name}@kubernetes.io", which
# must already exist.
#
ALL_PROD_BUCKETS=(
    "csi"
    "cni"
    "cri-tools"
    "kind"
)

# Regions for prod GCR.
PROD_REGIONS=(us eu asia)

# Minimum time we expect to keep prod GCS artifacts.
PROD_RETENTION="10y"

# Make a prod GCR repository and grant access to it.
#
# $1: The GCP project name (GCR names == project names)
function ensure_prod_gcr() {
    if [ $# -ne 1 -o -z "$1" ]; then
        echo "ensure_prod_gcr(project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"

    color 6 "Ensuring the GCR exists and is readable"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        ensure_gcr_repo "${project}" "${r}"
    done 2>&1 | indent

    color 6 "Empowering GCR admins"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        empower_gcr_admins "${project}" "${r}"
    done 2>&1 | indent

    color 6 "Empowering image promoter"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        empower_artifact_promoter "${project}" "${r}"
    done 2>&1 | indent

}

# Make a prod GCS bucket and grant access to it.  We need whole buckets for
# this because we want to grant minimal permissions, but there's no concept of
# permissions on a "subdirectory" of a bucket.  If we had a GCS promoter akin
# to the GCR promoter, we might have used a single bucket, but we don't have
# that yet.
#
# $1: The GCP project to make the bucket
# $2: The bucket, including gs:// prefix
# $3: The group email to empower (optional)
function ensure_prod_gcs_bucket() {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_prod_gcs_bucket(project, bucket, [group]) requires 2 or 3 arguments" >&2
        return 1
    fi
    local project="${1}"
    local bucket="${2}"
    local group="${3:-}"

    color 6 "Ensuring the GCS bucket exists and is readable"
    ensure_public_gcs_bucket "${project}" "${bucket}"

    color 6 "Ensuring the bucket retention policy is set"
    ensure_gcs_bucket_retention "${bucket}" "${PROD_RETENTION}"

    color 6 "Empowering GCS admins"
    empower_gcs_admins "${project}" "${bucket}"

    if [ -n "${group}" ]; then
        color 6 "Empowering ${group} to write to the bucket"
        empower_group_to_write_gcs_bucket "${group}" "${bucket}"
    fi
}

# Grant access to "fake prod" projects for tol testing
# $1: The GCP project
# $2: The googlegroups group
function empower_group_to_fake_prod() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_to_fake_prod(project, group) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local group="$2"

    color 6 "Empowering $group as project viewer in $project"
    empower_group_as_viewer "${project}" "${group}"

    color 6 "Empowering $group for GCR in $project"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        empower_group_to_write_gcr "${group}" "${project}" "${r}"
    done
}

#
# main()
#

# Create all prod artifact projects.
color 6 "Ensuring all prod projects"
for prj in "${ALL_PROD_PROJECTS[@]}"; do
    color 6 "Ensuring project exists: ${prj}"
    ensure_project "${prj}"

    color 6 "Enabling the container registry API: ${prj}"
    enable_api "${prj}" containerregistry.googleapis.com

    color 6 "Enabling the container analysis API: ${prj}"
    enable_api "${prj}" containeranalysis.googleapis.com

    color 6 "Ensuring the GCR repository: ${prj}"
    ensure_prod_gcr "${prj}" 2>&1 | indent

    color 6 "Enabling the GCS API: ${prj}"
    enable_api "${prj}" storage-component.googleapis.com

    color 6 "Ensuring the GCS bucket: gs://${prj}"
    ensure_prod_gcs_bucket "${prj}" "gs://${prj}" 2>&1 | indent
done 2>&1 | indent

# Create all prod GCS buckets.
color 6 "Ensuring all prod buckets"
for sfx in "${ALL_PROD_BUCKETS[@]}"; do
    color 6 "Ensuring the GCS bucket: gs://k8s-artifacts-${sfx}"
    ensure_prod_gcs_bucket \
        "${PROD_PROJECT}" \
        "gs://k8s-artifacts-${sfx}" \
        "k8s-infra-push-${sfx}@kubernetes.io" \
        | indent
done 2>&1 | indent

color 6 "Handling special cases"
(
    # Special case: set the web policy on the prod bucket.
    color 6 "Configuring the web policy on the prod bucket"
    ensure_gcs_web_policy "gs://${PROD_PROJECT}"

    # Special case: rsync static content into the prod bucket.
    color 6 "Copying static content into the prod bucket"
    upload_gcs_static_content \
        "gs://${PROD_PROJECT}" \
        "${SCRIPT_DIR}/static/prod-storage"

    # Special case: enable vulnerability scanning on the prod GCR.
    color 6 "Enabling GCR vulnerability scanning in the prod GCR"
    enable_api "${PROD_PROJECT}" containerscanning.googleapis.com

    # Special case: enable people to read vulnerability reports.
    color 6 "Empowering artifact-security group to real vulnerability reports"
    SEC_GROUP="k8s-infra-artifact-security@kubernetes.io"
    empower_group_as_viewer "${PROD_PROJECT}" "${SEC_GROUP}"
    gcloud \
        projects add-iam-policy-binding "${PROD_PROJECT}" \
        --member "group:${SEC_GROUP}" \
        --role roles/containeranalysis.occurrences.viewer

    # Special case: grant the image promoter testing group access to their fake
    # prod projects.
    color 6 "Empowering staging-cip-test group to fake-prod"
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
    color 6 "Empowering test-prod promoter to promoter staging GCR"
    empower_svcacct_to_admin_gcr \
        $(svc_acct_email "${PROMOTER_TEST_PROD_PROJECT}" "${PROMOTER_SVCACCT}") \
        "${PROMOTER_TEST_STAGING_PROJECT}"

    # Special case: grant the image promoter test service account access to
    # their testing project (used for running e2e tests for the promoter auditing
    # mechanism).
    color 6 "Empowering test-prod promoter to test-prod auditor"
    empower_service_account_for_cip_auditor_e2e_tester \
        $(svc_acct_email "${GCR_AUDIT_TEST_PROD_PROJECT}" "${PROMOTER_SVCACCT}") \
        "${GCR_AUDIT_TEST_PROD_PROJECT}"

    # Special case: grant the GCR backup-test svcacct access to the "backup-test
    # prod" project (which models the real $PROD_PROJECT) so it can write the
    # source images and then execute tests of the backup system.  This svcacct
    # already has access to the "backup-test prod backup" project (which models the
    # real $PRODBAK_PROJECT).  We don't want this same power for the non-test
    # backup system, so a compromised promoter can't nuke backups.
    color 6 "Empowering backup-test-prod promoter to backup-test-prod GCR"
    for r in "${PROD_REGIONS[@]}"; do
        color 3 "region $r"
        empower_svcacct_to_write_gcr \
            $(svc_acct_email "${GCR_BACKUP_TEST_PRODBAK_PROJECT}" "${PROMOTER_SVCACCT}") \
            "${GCR_BACKUP_TEST_PROD_PROJECT}" \
            "${r}"
    done 2>&1 | indent

    # Special case: grant the Release Managers group access to their fake
    # prod project.
    color 6 "Empowering staging-kubernetes to release test-prod"
    empower_group_to_fake_prod \
        "${RELEASE_TESTPROD_PROJECT}" \
        "k8s-infra-staging-kubernetes@kubernetes.io"

    # Special case: grant the k8s-staging-kubernetes Cloud Build account access to
    # write to the primary test prod GCS bucket. This currently is a requirement
    # for anago.
    color 6 "Empowering release-staging GCB to release test-prod"
    empower_svcacct_to_write_gcs_bucket \
        "${RELEASE_STAGING_CLOUDBUILD_ACCOUNT}" \
        "gs://${RELEASE_TESTPROD_PROJECT}"

    # Special case: don't use retention on cip-test buckets
    color 6 "Removing retention on promoter test-prod"
    gsutil retention clear gs://k8s-cip-test-prod

    # Special case: give Cloud Run Admin privileges to the group that will
    # administer the cip-auditor (so that they can deploy the auditor to Cloud Run).
    color 6 "Empowering artifact-admins to release prod auditor"
    empower_group_to_admin_artifact_auditor \
        "${PROD_PROJECT}" \
        "k8s-infra-artifact-admins@kubernetes.io"
    # Special case: create/add-permissions for necessary service accounts for the auditor.
    color 6 "Empowering artifact auditor"
    empower_artifact_auditor "${PROD_PROJECT}"
    empower_artifact_auditor_invoker "${PROD_PROJECT}"

    # Special case: empower Kubernetes service account to authenticate as a GCP
    # service account.
    #
    # For write access to k8s-artifacts-prod GCR.
    color 6 "Empowering promoter namespace to use prod promoter svcacct"
    for project in "${PROW_TRUSTED_BUILD_CLUSTER_PROJECTS[@]}"; do
        empower_ksa_to_svcacct \
            "${project}.svc.id.goog[test-pods/k8s-infra-gcr-promoter]" \
            "${PROD_PROJECT}" \
            $(svc_acct_email "${PROD_PROJECT}" "${PROMOTER_SVCACCT}")
    done
    # For write access to k8s-artifacts-prod-bak GCR. This is only for backups.
    color 6 "Empowering promoter-bak namespace to use prod-bak promoter svcacct"
    for project in "${PROW_TRUSTED_BUILD_CLUSTER_PROJECTS[@]}"; do
        empower_ksa_to_svcacct \
            "${project}.svc.id.goog[test-pods/k8s-infra-gcr-promoter-bak]" \
            "${PRODBAK_PROJECT}" \
            $(svc_acct_email "${PRODBAK_PROJECT}" "${PROMOTER_SVCACCT}")
    done
    # For write access to:
    #   (1) k8s-gcr-backup-test-prod GCR
    #   (2) k8s-gcr-backup-test-prod-bak GCR.
    # Even though we only grant authentication to 1 SA
    # (k8s-infra-gcr-promoter@k8s-gcr-backup-test-prod-bak.iam.gserviceaccount.com),
    # this SA has write access to the above 2 GCRs, fulfilling our needs.
    #
    # Also, note that the project name for the GKE cluster is "k8s-prow-builds",
    # which is the non-trusted Prow cluster.
    color 6 "Empowering promoter-test namespace to use backup-test-prod-bak promoter svcacct"
    for project in "${PROW_UNTRUSTED_BUILD_CLUSTER_PROJECTS[@]}"; do
        empower_ksa_to_svcacct \
            "${project}.svc.id.goog[test-pods/k8s-infra-gcr-promoter-test]" \
            "${GCR_BACKUP_TEST_PRODBAK_PROJECT}" \
            $(svc_acct_email "${GCR_BACKUP_TEST_PRODBAK_PROJECT}" "${PROMOTER_SVCACCT}")
    done

    color 6 "Ensuring prod promoter vuln scanning svcacct exists"
    ensure_service_account \
        "${PROD_PROJECT}" \
        "${PROMOTER_VULN_SCANNING_SVCACCT}" \
        "k8s-infra container image vuln scanning"

    color 6 "Empowering promoter-scanning namespace to use prod promoter vuln scanning svcacct"
    for project in "${PROW_TRUSTED_BUILD_CLUSTER_PROJECTS[@]}"; do
        empower_ksa_to_svcacct \
            "${project}.svc.id.goog[test-pods/k8s-infra-gcr-vuln-scanning]" \
            "${PROD_PROJECT}" \
            $(svc_acct_email "${PROD_PROJECT}" "${PROMOTER_VULN_SCANNING_SVCACCT}")
    done
) 2>&1 | indent

color 6 "Done"
