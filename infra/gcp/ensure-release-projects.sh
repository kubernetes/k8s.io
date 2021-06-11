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

mapfile -t PROJECTS < <(k8s_infra_projects "release")
readonly PROJECTS

if [ $# = 0 ]; then
    # default to all release projects
    set -- "${PROJECTS[@]}"
fi

readonly RELEASE_PROJECT_SERVICES=(
    cloudbuild.googleapis.com
    cloudkms.googleapis.com
    containerregistry.googleapis.com
    secretmanager.googleapis.com
    storage-component.googleapis.com
)

for PROJECT; do

    if ! k8s_infra_project "release" "${PROJECT}" >/dev/null; then
        color 1 "Skipping unrecognized release project name: ${PROJECT}"
        continue
    fi

    color 3 "Configuring: ${PROJECT}"

    # The names of the buckets
    STAGING_BUCKET="gs://${PROJECT}" # used by humans
    GCB_BUCKET="gs://${PROJECT}-gcb" # used by GCB
    ALL_BUCKETS=("${STAGING_BUCKET}" "${GCB_BUCKET}")

    # Make the project, if needed
    color 6 "Ensuring project exists: ${PROJECT}"
    ensure_project "${PROJECT}"

    for group in ${RELEASE_ADMINS} ${RELEASE_MANAGERS} ${RELEASE_VIEWERS}; do
        # Enable admins to use the UI
        color 6 "Empowering ${group} as project viewers"
        empower_group_as_viewer "${PROJECT}" "${group}"
    done

    # Enable services for release projects and their direct dependencies; prune anything else
    color 6 "Ensuring only necessary services are enabled for release project: ${PROJECT}"
    ensure_only_services "${PROJECT}" "${RELEASE_PROJECT_SERVICES[@]}"

    # Every project gets a GCR repo

    # Push an image to trigger the bucket to be created
    color 6 "Ensuring the registry exists and is readable"
    ensure_gcr_repo "${PROJECT}"

    # Enable GCR admins
    color 6 "Empowering GCR admins"
    empower_gcr_admins "${PROJECT}"

    # Enable GCR writers
    for group in ${RELEASE_ADMINS} ${RELEASE_MANAGERS}; do
        color 6 "Empowering ${group} to GCR"
        empower_group_to_write_gcr "${group}" "${PROJECT}"
    done

    # Every project gets some GCS buckets

    for BUCKET in "${ALL_BUCKETS[@]}"; do
        color 3 "Configuring bucket: ${BUCKET}"

        # Create the bucket
        color 6 "Ensuring the bucket exists and is world readable"
        ensure_public_gcs_bucket "${PROJECT}" "${BUCKET}"

        # Enable admins on the bucket
        color 6 "Empowering GCS admins"
        empower_gcs_admins "${PROJECT}" "${BUCKET}"

        # Enable writers on the bucket
        for group in ${RELEASE_ADMINS} ${RELEASE_MANAGERS}; do
            color 6 "Empowering ${group} to GCS"
            empower_group_to_write_gcs_bucket "${group}" "${BUCKET}"
        done
    done

    # Enable GCB and Prow to build and push images.

    # Let project writers use GCB.
    for group in ${RELEASE_ADMINS} ${RELEASE_MANAGERS}; do
        color 6 "Empowering ${group} as GCB editors"
        empower_group_for_gcb "${PROJECT}" "${group}"
    done

    # Let prow trigger builds and access the scratch bucket
    serviceaccount="${GCB_BUILDER_SVCACCT}"
    principal="serviceAccount:${serviceaccount}"

    color 6 "Ensuring ${serviceaccount} can use GCB in project: ${PROJECT}"
    ensure_project_role_binding "${PROJECT}" "${principal}" "roles/cloudbuild.builds.builder"
    ensure_gcs_role_binding "${GCB_BUCKET}" "${principal}" "objectCreator"
    ensure_gcs_role_binding "${GCB_BUCKET}" "${principal}" "objectViewer"

    # Let project admins use KMS.
    color 6 "Empowering ${RELEASE_ADMINS} as KMS admins"
    empower_group_for_kms "${PROJECT}" "${RELEASE_ADMINS}"

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

for BUCKET in "${RELEASE_BUCKETS[@]}"; do
    color 3 "Configuring bucket: ${BUCKET}"

    # Create the bucket
    color 6 "Ensuring the bucket exists and is world readable"
    ensure_public_gcs_bucket "k8s-release" "${BUCKET}"

    # Enable admins on the bucket
    color 6 "Empowering GCS admins"
    empower_gcs_admins "k8s-release" "${BUCKET}"

    # Enable prow to write to the bucket
    empower_svcacct_to_write_gcs_bucket "${PROW_BUILD_SERVICE_ACCOUNT}" "${BUCKET}"

    # Enable writers on the bucket
    for group in ${RELEASE_ADMINS} ${RELEASE_MANAGERS}; do
        color 6 "Empowering ${group} to GCS"
        empower_group_to_write_gcs_bucket "${group}" "${BUCKET}"
    done
done

color 6 "Ensure auto-deletion policies are set for CI buckets"
ensure_gcs_bucket_auto_deletion "gs://k8s-release-dev" 90
ensure_gcs_bucket_auto_deletion "gs://k8s-release-pull" 14
