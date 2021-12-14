#!/usr/bin/env bash

# Copyright 2021 The Kubernetes Authors.
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

# This script is used to create a new "staging" repo in Artifact Repository.
#
# Each sub-project that needs to publish artifacts should have their
# own staging Artifact Repository repo.
#
# Each staging repo exists in its own GCP project, and is writable by a
# dedicated googlegroup.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"
. "${SCRIPT_DIR}/ensure-staging-storage.sh"

function usage() {
    echo "usage: $0 [repo...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all staging repos" > /dev/stderr
    echo "  $0 coredns # just do one" > /dev/stderr
    echo > /dev/stderr
}

#
# Staging functions
#

# Provision and configure a "staging" GCP project, intended to hold 
# temporary release artifacts in a pre-provisioned GCS bucket or 
# GAR. The intent is to then promote some of these artifacts to
# production, which is long-lived and immutable.
#
# Artifacts are ideally written here via automation, either via GCB
# builds run within the project, or by prowjobs running in a trusted
# cluster (currently: k8s-infra-prow-build-trusted)
#
# As a fallback, a per-project group of humans is given access to
# manually write artifacts andtrigger GCB builds in the project
#
# $1: GCP project name (e.g. "k8s-staging-foo")
# $2: Group for manual access (e.g. "k8s-infra-staging-foo@kubernetes.io")
function ensure_releng_gar_project() {
    if [ $# != 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(gcp_project, writers_group) requires 2 arguments" >&2
        return 1
    fi
    local project="${1}"
    local writers="${2}"

    # Ensure staging project GAR

    color 3 "Ensuring staging GAR repo: gcr.io/${project}"
    ensure_staging_gar_repo "${project}" "${writers}" 2>&1 | indent
}

function ensure_releng_gar_projects() {
    color 6 "Ensuring staging projects..."

    # default to all staging projects
    if [ $# = 0 ]; then
        set -- "${RELEASE_STAGING_PROJECTS[@]}"
    fi

    for arg in "${@}"; do
        local repo="${arg#k8s-staging-}"
        local project="k8s-staging-${repo}"
        if ! k8s_infra_project "staging" "${project}" >/dev/null; then
            color 1 "Skipping unrecognized staging project name: ${project}"
            continue
        fi

        color 3 "Configuring staging project: ${project}"
        ensure_releng_gar_project \
            "${project}" \
            "k8s-infra-staging-${repo}@kubernetes.io" \
            2>&1 | indent

    done

    color 6 "Done"
}

ensure_releng_gar_projects "${@}"
