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

# This script is used to ensure Release Managers have the appropriate access
# to SIG Release GCP projects.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 [project...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all release projects" > /dev/stderr
    echo "  $0 k8s-release-test-prod # just do one" > /dev/stderr
    echo > /dev/stderr
}

# NB: Please keep this sorted.
PROJECTS=(
    k8s-release
    k8s-release-test-prod
)

if [ $# = 0 ]; then
    # default to all release projects
    set -- "${PROJECTS[@]}"
fi

ADMINS="k8s-infra-release-admins@kubernetes.io"
WRITERS="k8s-infra-release-editors@kubernetes.io"
VIEWERS="k8s-infra-release-viewers@kubernetes.io"

for PROJECT; do
    color 3 "Configuring: ${PROJECT}"

    # The names of the buckets
    STAGING_BUCKET="gs://${PROJECT}" # used by humans
    GCB_BUCKET="gs://${PROJECT}-gcb" # used by GCB
    ALL_BUCKETS=("${STAGING_BUCKET}" "${GCB_BUCKET}")

    # Make the project, if needed
    color 6 "Ensuring project exists: ${PROJECT}"
    ensure_project "${PROJECT}"

    for group in ${ADMINS} ${WRITERS} ${VIEWERS}; do
        # Enable admins to use the UI
        color 6 "Empowering ${group} as project viewers"
        empower_group_as_viewer "${PROJECT}" "${group}"
    done

    # Every project gets a GCR repo

    # Enable container registry APIs
    color 6 "Enabling the container registry API"
    enable_api "${PROJECT}" containerregistry.googleapis.com

    # Push an image to trigger the bucket to be created
    color 6 "Ensuring the registry exists and is readable"
    ensure_gcr_repo "${PROJECT}"

    # Enable GCR admins
    color 6 "Empowering GCR admins"
    empower_gcr_admins "${PROJECT}"

    # Enable GCR writers
    for group in ${ADMINS} ${WRITERS}; do
        color 6 "Empowering ${group} to GCR"
        empower_group_to_write_gcr "${group}" "${PROJECT}"
    done

    # Every project gets some GCS buckets

    # Enable GCS APIs
    color 6 "Enabling the GCS API"
    enable_api "${PROJECT}" storage-component.googleapis.com

    for BUCKET in "${ALL_BUCKETS[@]}"; do
        color 3 "Configuring bucket: ${BUCKET}"

        # Create the bucket
        color 6 "Ensuring the bucket exists and is world readable"
        ensure_public_gcs_bucket "${PROJECT}" "${BUCKET}"

        # Enable admins on the bucket
        color 6 "Empowering GCS admins"
        empower_gcs_admins "${PROJECT}" "${BUCKET}"

        # Enable writers on the bucket
        for group in ${ADMINS} ${WRITERS}; do
            color 6 "Empowering ${group} to GCS"
            empower_group_to_write_gcs_bucket "${group}" "${BUCKET}"
        done
    done

    # Enable GCB and Prow to build and push images.

    # Enable GCB APIs
    color 6 "Enabling the GCB API"
    enable_api "${PROJECT}" cloudbuild.googleapis.com

    # Let project writers use GCB.
    for group in ${ADMINS} ${WRITERS}; do
        color 6 "Empowering ${group} as GCB editors"
        empower_group_for_gcb "${PROJECT}" "${group}"
    done

    # Let prow trigger builds and access the scratch bucket
    color 6 "Empowering Prow"
    empower_prow "${PROJECT}" "${GCB_BUCKET}"

    # Enable KMS APIs
    color 6 "Enabling the KMS API"
    enable_api "${PROJECT}" cloudkms.googleapis.com

    # Let project admins use KMS.
    color 6 "Empowering ${ADMINS} as KMS admins"
    empower_group_for_kms "${PROJECT}" "${ADMINS}"

    color 6 "Done"
done

## Special case: setup buckets that are used by CI

# community-owned equivalents to gs://kubernetes-release-{dev,pull}
RELEASE_BUCKETS=(
  "gs://k8s-release-dev"
  "gs://k8s-release-dev-asia"
  "gs://k8s-release-dev-eu"
  "gs://k8s-release-pull"
)
PROW_BUILD_SVCACCT=$(svc_acct_email "k8s-infra-prow-build" "prow-build")

for BUCKET in "${RELEASE_BUCKETS[@]}"; do
    color 3 "Configuring bucket: ${BUCKET}"

    # Create the bucket
    color 6 "Ensuring the bucket exists and is world readable"
    ensure_public_gcs_bucket "k8s-release" "${BUCKET}"

    # Enable admins on the bucket
    color 6 "Empowering GCS admins"
    empower_gcs_admins "k8s-release" "${BUCKET}"

    # Enable prow to write to the bucket
    # TODO(spiffxp): I almost guarantee prow will need admin privileges but
    #                let's start restricted and find out
    empower_svcacct_to_write_gcs_bucket "${PROW_BUILD_SVCACCT}" "${BUCKET}"

    # Enable writers on the bucket
    for group in ${ADMINS} ${WRITERS}; do
        color 6 "Empowering ${group} to GCS"
        empower_group_to_write_gcs_bucket "${group}" "${BUCKET}"
    done
done

color 6 "Ensure auto-deletion policies are set for CI buckets"
ensure_gcs_bucket_auto_deletion "gs://k8s-release-dev" 90
ensure_gcs_bucket_auto_deletion "gs://k8s-release-pull" 14
