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

PROJECT=$(k8s_infra_project "public" "k8s-conform")
readonly PROJECT

readonly CONFORMANCE_SERVICES=(
    # secretmanager to host service-account keys
    secretmanager.googleapis.com
    # storage-api to store results in GCS via JSON API
    storage-api.googleapis.com
    # storage-component to store results in GCS via XML API
    storage-component.googleapis.com
)

readonly CONFORMANCE_RETENTION="10y"

# "Offering" comes from https://github.com/cncf/k8s-conformance/blob/master/terms-conditions/Certified_Kubernetes_Terms.md
# NB: Please keep this sorted.
readonly CONFORMANCE_OFFERINGS=(
    cri-o
    huaweicloud
    inspur
    provider-openstack
    s390x-k8s
)

if [ $# = 0 ]; then
    # default to all conformance buckets
    set -- "${CONFORMANCE_OFFERINGS[@]}"
fi

# Make the project, if needed
function ensure_conformance_project() {
    color 6 "Ensuring project exists: ${PROJECT}"
    ensure_project "${PROJECT}"

    # Enable GCS APIs
    color 6 "Ensuring only necessary services are enabled for conformance project: ${PROJECT}"
    ensure_only_services "${PROJECT}" "${CONFORMANCE_SERVICES[@]}"
}

# ensure_conformance_bucket ensure that:
# - the given bucket exists and is publicly readable
# - the given bucket has the conformance retention policy setup
# - the given bucket is writable by the given group
function ensure_conformance_bucket() {
    local bucket="${1}"
    local writers="${2}"

    color 6 "Ensuring ${PROJECT} contains world readadble GCS bucket: ${bucket}"
    ensure_public_gcs_bucket "${PROJECT}" "${bucket}"

    color 6 "Empowering GCS admins for GCS bucket: ${bucket}"
    empower_gcs_admins "${PROJECT}" "${bucket}"

    color 6 "Ensuring ${bucket} retention policy is set to: ${CONFORMANCE_RETENTION}"
    ensure_gcs_bucket_retention "${bucket}" "${CONFORMANCE_RETENTION}"

    color 6 "Empowering ${writers} to write to GCS bucket: ${bucket}"
    empower_group_to_write_gcs_bucket "${writers}" "${bucket}"

}

# ensure_conformance_serviceaccount ensures that:
# - a serviceaccount of the given name exists in PROJECT
# - it can write to the given bucket
# - it has a private key stored in a secret in PROJECT accessible to the given group
function ensure_conformance_serviceaccount() {
    local name="${1}"
    local bucket="${2}"
    local secret_accessors="${3}"

    local email="$(svc_acct_email "${PROJECT}" "${name}")"
    local secret="${name}-key"
    local private_key_file="${TMPDIR}/key.json"

    color 6 "Ensuring service account exists: ${email}"
    ensure_service_account "${PROJECT}"  "${name}" "Grants write access to ${bucket}"

    color 6 "Ensuring ${PROJECT} contains secret ${secret} with private key for ${email}"
    ensure_serviceaccount_key_secret "${PROJECT}" "${secret}" "${email}"

    color 6 "Empowering ${secret_accessors} to access secret: ${secret}"
    ensure_secret_role_binding \
        "projects/${PROJECT}/secrets/${secret}" \
        "group:${secret_accessors}" \
        "roles/secretmanager.secretAccessor"

    color 6 "Empowering ${email} to write to ${bucket}"
    empower_svcacct_to_write_gcs_bucket "${email}"  "${bucket}"
}

ensure_conformance_project

color 6 "Ensuring all conformance buckets"
for OFFERING; do
    # The GCS bucket to hold conformance results for this offering
    BUCKET="gs://${PROJECT}-${OFFERING}" # used by humans
    # The group that can write to GCS bucket
    BUCKET_WRITERS="k8s-infra-conform-${OFFERING}@kubernetes.io"
    # The service account that can write to the GCS bucket
    SERVICE_ACCOUNT_NAME="service-${OFFERING}"

    if ! (printf '%s\n' "${CONFORMANCE_OFFERINGS[@]}" | grep -q "^${OFFERING}$"); then
      color 2 "Skipping unrecognized conformance offering: ${OFFERING}"
      continue
    fi

    color 3 "Ensuring conformance bucket for ${OFFERING}"
    ensure_conformance_bucket "${BUCKET}" "${BUCKET_WRITERS}" 2>&1 | indent

    color 3 "Ensuring conformance service account for ${OFFERING}" 2>&1 | indent
    ensure_conformance_serviceaccount "${SERVICE_ACCOUNT_NAME}" "${BUCKET}" "${BUCKET_WRITERS}"
done 2>&1 | indent
color 6 "Done"
