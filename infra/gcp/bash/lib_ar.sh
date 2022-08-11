#!/usr/bin/env bash

# Copyright 2022 The Kubernetes Authors.
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

# Artifact Registry utility functions
#
# This is intended to be very general-purpose and "low-level".  Higher-level
# policy does not belong here.
#
# This MUST NOT be used directly. Source it via lib.sh instead.

# Grant write privileges on a AR to a group
# $1: The googlegroups group email
# $2: The GCP project
# $3: The AR region
function empower_group_to_write_ar() {
    if [ $# -lt 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "empower_group_to_write_ar(group_name, project, location) requires 3 arguments" >&2
        return 1
    fi
    local group="$1"
    local project="$2"
    local location="$3"

    ensure_ar_repository_role_binding "images" "${group}" "roles/artifactregistry.repoAdmin" "${project}" "${location}"
}

function ensure_public_ar_registry() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(project, location) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local location="$2"

    ensure_ar_repository_role_binding "images" "allUsers" "roles/artifactregistry.reader" "${project}" "${location}"
}

function empower_ar_admins() {
    # Reusing GCR Admins groups
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_ar_admins(project, location) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local location="$2"

    ensure_ar_repository_role_binding "images" "group:${GCR_ADMINS}" "roles/artifactregistry.admin" "${project}" "${location}"
}

# Ensure the AR registry exists and is world-readable.
# $1: The GCP project
# $2: The AR location (optional)
function ensure_ar_repo() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "ensure_ar_repo(project, location) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local location="$2"
    # AR Repos will always be called images. Format LOCATION-docker.pkg.dev/PROJECT_ID/images/foobar:latest
    if ! gcloud artifacts repositories describe images --location="${location}" --project="${project}" >/dev/null 2>&1; then
        gcloud artifacts repositories create images \
            --repository-format=docker \
            --location="${location}" \
            --project="${project}"
    fi

    ensure_public_ar_registry "${project}" "${location}"
}

# Ensure that IAM binding is present for repositories
# Arguments:
#   $1:  The repository name (e.g. "images")
#   $2:  The principal (e.g. "group:k8s-infra-foo@kubernetes.io")
#   $3:  The role name (e.g. "roles/storage.objectAdmin")
#   $4:  The project (e.g. "k8s-artifacts-prod")
#   $5:  The location (e.g. "europe")
function ensure_ar_repository_role_binding() {
    if [ ! $# -eq 5 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
        echo "ensure_ar_repository_role_binding(repository, principal, role, project, location) requires 5 arguments" >&2
        return 1
    fi

    local repository="${1}"
    local principal="${2}"
    local role="${3}"

    _ensure_resource_role_binding "artifacts repositories" "${repository}" "${principal}" "${role}" "${project}" "${location}"
}
