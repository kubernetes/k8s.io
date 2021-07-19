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

# Ensure the given GCS bucket exists in the given project with auto-deletion
# enabled after a default or optionally specified number of days, and
# appropriate permissions for prow, on-call, and release-managers
#
# $1: The GCP project (e.g. k8s-release)
# $2: The GCS bucket (e.g. gs://k8s-release-dev)
# [$3]: The number of days after which objects are auto-delete (e.g. 14, default: 90)
function ensure_kubernetes_ci_gcs_bucket() {
    if [ $# -lt 2 ] || [ $# -gt 4 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "${3:-"x"}" ]; then
        echo "${FUNCNAME[0]}(project, gcs_bucket, [auto_deletion_days])" >&2
        return 1
    fi
    local project="${1}"
    local bucket="${2}"
    local auto_deletion_days="${3:-"90"}"

    color 6 "Ensuring ${bucket} exists and is world readable in project: ${project}"
    ensure_public_gcs_bucket "${project}" "${bucket}"

    color 6 "Ensuring ${bucket} has auto-deletion of ${auto_deletion_days} days"
    ensure_gcs_bucket_auto_deletion "${bucket}" "${auto_deletion_days}"

    color 6 "Ensuring GCS admins can admin ${bucket} in project: ${project}"
    empower_gcs_admins "${project}" "${bucket}"

    color 6 "Ensuring prow on-call can admin ${bucket} in project: ${project}"
    empower_group_to_admin_gcs_bucket "k8s-infra-prow-oncall@kubernetes.io" "${bucket}"

    color 6 "Ensuring prow service account ${PROW_BUILD_SERVICE_ACCOUNT} can write to ${bucket} in project: ${project}"
    empower_svcacct_to_write_gcs_bucket "${PROW_BUILD_SERVICE_ACCOUNT}" "${bucket}"

    # Empower prow jobs running on google.com-owned k8s-prow or k8s-prow-builds
    # clusters to write CI artifacts to the bucket
    # TODO(spiffxp): remove this once we've migrated the jobs that rely on this account
    #                to community-owned build cluster(s)
    color 6 "Ensuring prow service account ${PR_KUBEKINS_SERVICE_ACCOUNT} can write to ${bucket} in project: ${project}"
    empower_svcacct_to_write_gcs_bucket "${PR_KUBEKINS_SERVICE_ACCOUNT}" "${bucket}"

    # Enable access logs to identify what pr-kubekins writes to this bucket
    # TODO(spiffxp): consider disabling this once migration is complete
    color 6 "Ensuring GCS access logs enabled for ${bucket} in project: ${project}"
    ensure_gcs_bucket_logging "${bucket}"

    # TODO(spiffxp): I'm not actually sure this makes sense. These groups don't
    #                have permissions to do this with the google.com-owned bucket
    #                today. These buckets should be strictly-CI unless there are
    #                very exceptional circumstances (which is when I'd suggest we
    #                escalate to the admins above)
    for group in ${RELEASE_ADMINS} ${RELEASE_MANAGERS}; do
        color 6 "Ensuring group ${group} can write to ${bucket} in project: ${project}"
        empower_group_to_write_gcs_bucket "${group}" "${bucket}"
    done

}

function special_case_kubernetes_ci_buckets() {
  # community-owned equivalents to gs://kubernetes-release-{dev,pull}
  ensure_kubernetes_ci_gcs_bucket "k8s-release" "gs://k8s-release-dev"
  # TODO: we're squatting on these bucket names until we decide what to do:
  # - these buckets aren't setup as regional buckets in ASIA and EU -> delete and recreate properly?
  # - the google.com-owned -asia and -eu buckets are unpopulated -> forget the whole thing?
  ensure_kubernetes_ci_gcs_bucket "k8s-release" "gs://k8s-release-dev-asia"
  ensure_kubernetes_ci_gcs_bucket "k8s-release" "gs://k8s-release-dev-eu"
  # TODO(https://github.com/kubernetes/test-infra/issues/18789) remove this bucket when no longer needed
  ensure_kubernetes_ci_gcs_bucket "k8s-release" "gs://k8s-release-pull" 14
}

color 3 "Special case: ensuring GCS buckets for kubernetes CI artifacts exist"
special_case_kubernetes_ci_buckets 2>&1 | indent
