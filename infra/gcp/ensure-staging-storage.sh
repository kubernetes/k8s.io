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

# This script is used to create a new "staging" repo in GCR, and a bucket in GCS.
#
# Each sub-project that needs to publish artifacts should have their
# own staging GCR repo & GCS bucket.
#
# Each staging bucket & repo exists in its own GCP project, and is writable by a
# dedicated googlegroup.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 [repo...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all staging repos" > /dev/stderr
    echo "  $0 coredns # just do one" > /dev/stderr
    echo > /dev/stderr
}

STAGING_PROJECTS=(
    coredns
    cip-test
    cluster-api
    csi
    kops
    publishing-bot
)
if [ $# = 0 ]; then
    # default to all staging projects
    set -- "${STAGING_PROJECTS[@]}"
fi

for REPO; do
    color 3 "${REPO}"

    # The GCP project name.
    PROJECT="k8s-staging-${REPO}"

    # The group that can write to this staging repo.
    WRITERS="k8s-infra-staging-${REPO}@kubernetes.io"

    # The name of the bucket
    BUCKET="gs://${PROJECT}"

    # A short retention - it can always be raised, but it is hard to lower
    # We expect promotion within 30d, or for testing to "move on"
    # 30d is also short enough that people should notice occasionally,
    # and not accidentally think of the staging buckets as permanent.
    RETENTION=30d
    AUTO_DELETION_DAYS=30

    # Make the project, if needed
    color 6 "Ensuring project exists: ${PROJECT}"
    ensure_project "${PROJECT}"

    # Every project gets a GCR repo

    # Enable container registry APIs
    color 6 "Enabling the container registry API"
    enable_api "${PROJECT}" containerregistry.googleapis.com

    # Push an image to trigger the bucket to be created
    color 6 "Ensuring the registry exists and is readable"
    ensure_repo "${PROJECT}"

    # Enable GCR admins
    color 6 "Empowering GCR admins"
    empower_gcr_admins "${PROJECT}"

    # Enable repo writers
    color 6 "Empowering ${WRITERS} to GCR"
    empower_group_to_repo "${PROJECT}" "${WRITERS}"

    # Every project gets a GCS bucket

    # Enable GCS APIs
    color 6 "Enabling the GCS API"
    enable_api "${PROJECT}" storage-component.googleapis.com

    # Create the bucket
    color 6 "Ensuring the bucket exists and is world readable"
    ensure_gcs_bucket "${PROJECT}" "${BUCKET}"

    # Set bucket retention
    color 6 "Ensuring the bucket has retention of ${RETENTION}"
    ensure_gcs_bucket_retention "${BUCKET}" "${RETENTION}"

    # Set bucket auto-deletion
    color 6 "Ensuring the bucket has auto-deletion of ${AUTO_DELETION_DAYS} days"
    ensure_gcs_bucket_auto_deletion "${BUCKET}" "${AUTO_DELETION_DAYS}"

    # Enable admins on the bucket
    color 6 "Empowering GCS admins"
    empower_gcs_admins "${PROJECT}" "${BUCKET}"

    # Enable writers on the bucket
    color 6 "Empowering ${WRITERS} to GCS"
    empower_group_to_bucket "${WRITERS}" "${BUCKET}"

    color 6 "Done"
done
