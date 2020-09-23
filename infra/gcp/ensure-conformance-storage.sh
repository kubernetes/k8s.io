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

# This script is used to create the "k8s-conform" project and corresponding buckets in GCS.
#
# All conformance buckets are created in the "k8s-conform" GCP project, and are writable by
# dedicated Google groups.
#
# The buckets will have a layout which is readable by testgrid:
# (See also: https://github.com/kubernetes/test-infra/tree/master/gubernator#gcs-layout)
# * each test result is stored in a "directory" with some monotonically increasing run identifier (commonly unix epoch time for third party uploads)
# * they should contain a junit.*.xml file with the structured test results
# * they should (optionally but commonly) contain a build-log.txt with the raw test output
# * they should contain two small json files started.json and finished.json with some metadata

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 [repo...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all conformance repos" > /dev/stderr
    echo "  $0 coredns # just do one" > /dev/stderr
    echo > /dev/stderr
}

PROJECT="k8s-conform"

# NB: Please keep this sorted.
CONFORMANCE_BUCKETS=(
    capi-openstack
    cri-o
    huaweicloud
    s390x-k8s
)
if [ $# = 0 ]; then
    # default to all conformance buckets
    set -- "${CONFORMANCE_BUCKETS[@]}"
fi

# Make the project, if needed
color 6 "Ensuring project exists: ${PROJECT}"
ensure_project "${PROJECT}"

# Enable GCS APIs
color 6 "Enabling the GCS API"
enable_api "${PROJECT}" storage-component.googleapis.com

# Enable Secret Manager API
color 6 "Enabling the Secret Manager API"
enable_api "${PROJECT}" secretmanager.googleapis.com

color 6 "Ensuring all conformance buckets"
for REPO; do
    color 3 "Configuring conformance bucket for ${REPO}"

    # The group that can write to this conformance repo.
    BUCKET_WRITERS="k8s-infra-conform-${REPO}@kubernetes.io"

    # The names of the buckets
    BUCKET="gs://${PROJECT}-${REPO}" # used by humans

    # Every project gets some GCS buckets
    color 3 "Configuring bucket: ${BUCKET}"

    # Create the bucket
    color 6 "Ensuring the bucket exists and is world readable"
    ensure_public_gcs_bucket "${PROJECT}" "${BUCKET}"

    color 6 "Ensuring the GCS bucket retention policy is set: ${PROJECT}"
    RETENTION="10y"
    ensure_gcs_bucket_retention "${BUCKET}" "${RETENTION}"

    # Enable admins on the bucket
    color 6 "Empowering GCS admins"
    empower_gcs_admins "${PROJECT}" "${BUCKET}"

    # Enable writers on the bucket
    color 6 "Empowering ${BUCKET_WRITERS} to GCS"
    empower_group_to_write_gcs_bucket "${BUCKET_WRITERS}" "${BUCKET}"

    readonly SERVICE_ACCOUNT_NAME="service-${REPO}"
    readonly SERVICE_ACCOUNT_EMAIL="$(svc_acct_email "${PROJECT}" \
        "${SERVICE_ACCOUNT_NAME}")"
    readonly SECRET_ID="${SERVICE_ACCOUNT_NAME}-key"
    readonly TMP_DIR=$(mktemp -d "/tmp/${SERVICE_ACCOUNT_NAME}.XXXXXX")
    readonly KEY_FILE="${TMP_DIR}/key.json"

    # Clean tmp dir when exit
    trap 'rm -rf "${TMP_DIR}"' EXIT

    if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT_EMAIL}" \
        --project "${PROJECT}" >/dev/null 2>&1
    then
        color 6 "Creating service account: ${SERVICE_ACCOUNT_NAME}"
        ensure_service_account \
            "${PROJECT}" \
            "${SERVICE_ACCOUNT_NAME}" \
            "${SERVICE_ACCOUNT_NAME}"

        color 6 "Empowering service account: ${SERVICE_ACCOUNT_NAME} to GCS"
        empower_svcacct_to_write_gcs_bucket \
            "${SERVICE_ACCOUNT_EMAIL}" \
            "${BUCKET}"

        color 6 "Creating private key for service account: ${SERVICE_ACCOUNT_NAME}"
        gcloud iam service-accounts keys create "${KEY_FILE}" \
            --project "${PROJECT}" \
            --iam-account "${SERVICE_ACCOUNT_EMAIL}"
        
        color 6 "Creating secret to store private key"
        gcloud secrets create "${SECRET_ID}" \
            --project "${PROJECT}" \
            --replication-policy "automatic"

        color 6 "Adding private key to secret"
        gcloud secrets versions add "${SECRET_ID}" \
            --project "${PROJECT}" \
            --data-file "${KEY_FILE}"

        color 6 "Empowering ${BUCKET_WRITERS} for read secret"
        gcloud secrets add-iam-policy-binding "${SECRET_ID}" \
            --project "${PROJECT}" \
            --member "group:${BUCKET_WRITERS}" \
            --role "roles/secretmanager.secretAccessor"
    fi
done 2>&1 | indent
color 6 "Done"
