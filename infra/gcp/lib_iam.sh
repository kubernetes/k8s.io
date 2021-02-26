#!/usr/bin/env bash
#
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

# IAM utility functions
#
# This is intended to be very general-purpose and "low-level".  Higher-level
# policy does not belong here.
#
# This MUST NOT be used directly. Source it via lib.sh instead.

# Ensure that custom IAM role exists, creating one if needed
# Arguments:
#   $1:  The GCP project
#   $2:  The role name (e.g. "ServiceAccountLister")
#   $3:  The role title (e.g. "Service Account Lister")
#   $4:  The role description (e.g. "Can list ServiceAccounts.")
#   $5+: The role permissions (e.g. "iam.serviceAccounts.list")
# Example usage:
#   ensure_custom_iam_role \
#       kubernetes-public \
#       ServiceAccountLister \
#       "Service Account Lister" \
#       "Can list ServiceAccounts." \
#       iam.serviceAccounts.list
function ensure_custom_iam_role() {
    if [ $# -lt 5 ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] \
        || [ -z "${4}" ] || [ -z "${5}" ]
    then
        echo -n "ensure_custom_iam_role(gcp_project, name, title," >&2
        echo    " description, permission...) requires at least 5 arguments" >&2
        return 1
    fi

    local gcp_project="${1}"; shift
    local name="${1}"; shift
    local title="${1}"; shift
    local description="${1}"; shift
    local permissions; permissions=$(join_by , "$@")

    if ! gcloud --project "${gcp_project}" iam roles describe "${name}" \
        >/dev/null 2>&1
    then
        gcloud --project "${gcp_project}" --quiet \
            iam roles create "${name}" \
            --title "${title}" \
            --description "${description}" \
            --stage GA \
            --permissions "${permissions}"
    fi
}

# Ensure that custom IAM role exists and is in sync with definition in file
# Arguments:
#   $1:  The scope of the role (e.g. "org", "project:foobar")
#   $2:  The role name (e.g. "prow.viewer")
#   $3:  The file (e.g. "/path/to/file.yaml")
function ensure_custom_iam_role_from_file() {
    if [ ! $# -eq 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "ensure_custom_iam_role_from_file(scope, name, file) requires 3 arguments" >&2
        return 1
    fi

    local scope="${1}"
    local name="${2}"
    local file="${3}"
    local full_name="${name}"

    scope_flag=""
    if [[ "${scope}" == "org" ]]; then
        scope_flag="--organization ${GCP_ORG}" 
        full_name="organizations/${GCP_ORG}/roles/${name}"
    elif [[ "${scope}" =~ "^project:" ]]; then
        project=$(echo "${scope}" | cut -d: -f2-)
        scope_flag="--project ${project}"
        full_name="projects/${project}/roles/${name}"
    else
        echo "ensure_custom_iam_role_from_file(scope, name, file) scope must be one of 'org' or 'project:project-id'" >&2
        return 1
    fi

    tmp_dir=$(mktemp -d "/tmp/ensure-role-${name}-XXXXX")
    trap 'rm -rf "${tmp_dir}"' EXIT
    before="${tmp_dir}/before.${role}.yaml"
    ready="${tmp_dir}/ready.${role}.yaml"
    after="${tmp_dir}/after.${role}.yaml"

    # detect if we should create or update and dump role; silently ignore error
    verb="update"
    if ! (gcloud iam roles describe ${scope_flag} "${name}" >"${before}") >/dev/null 2>&1; then
      verb="create"
    fi

    # name is foo.bar, but gcloud wants scope/id/role/foo.bar in the file
    <"${file}" sed -e "s|^name: ${name}|name: ${full_name}|" >"${ready}"
    gcloud iam roles "${verb}" ${scope_flag} "${name}" --file "${ready}" > "${after}"

    # if they differ, ignore the error
    diff "${before}" "${after}" || true
}

# Return the full name of a custom IAM role defined at the org level
# Arguments:
#   $1:  The role name (e.g. "prow.viewer")
function custom_org_role_name() {
    if [ ! $# -eq 1 -o -z "$1" ]; then
        echo "custom_org_role_name(name) requires 1 arguments" >&2
        return 1
    fi
    
    local name="${1}"

    echo "organizations/${GCP_ORG}/roles/${name}"
}

# Ensure that IAM binding exists at org level
# Arguments:
#   $1:  The role name (e.g. "prow.viewer")
#   $2:  The file (e.g. "/path/to/file.yaml")
function ensure_org_role_binding() {
    if [ ! $# -eq 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_org_role_binding(principal, role) requires 2 arguments" >&2
        return 1
    fi

    local org="${GCP_ORG}"
    local principal="${1}"
    local role="${2}"

    gcloud \
        organizations add-iam-policy-binding "${GCP_ORG}" \
        --member "${principal}" \
        --role "${role}"
}

# Ensure that IAM binding exists at project level
# Arguments:
#   $1:  The project id (e.g. "k8s-infra-foo")
#   $2:  The principal (e.g. "group:k8s-infra-foo@kubernetes.io")
#   $3:  The role name (e.g. "roles/storage.objectAdmin")
function ensure_project_role_binding() {
    if [ ! $# -eq 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "ensure_project_role_binding(project, principal, role) requires 3 arguments" >&2
        return 1
    fi

    local project="${1}"
    local principal="${2}"
    local role="${3}"

    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "${principal}" \
        --role "${role}"
}

# Ensure that IAM binding has been removed from project
# Arguments:
#   $1:  The project id (e.g. "k8s-infra-foo")
#   $2:  The principal (e.g. "group:k8s-infra-foo@kubernetes.io")
#   $3:  The role name (e.g. "roles/foo.bar")
function ensure_removed_project_role_binding() {
    if [ ! $# -eq 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "ensure_removed_project_role_binding(project, principal, role) requires 3 arguments" >&2
        return 1
    fi

    local project="${1}"
    local principal="${2}"
    local role="${3}"

    _ensure_removed_resource_role_binding "projects" "${project}" "${principal}" "${role}"
}

# Ensure that IAM binding has been removed from organization
# Arguments:
#   $1:  The principal (e.g. "group:k8s-infra-foo@kubernetes.io")
#   $2:  The role name (e.g. "roles/foo.bar")
function ensure_removed_org_role_binding() {
    if [ ! $# -eq 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_removed_org_role_binding(principal, role) requires 2 arguments" >&2
        return 1
    fi

    local organization="${GCP_ORG}"
    local principal="${1}"
    local role="${2}"

    _ensure_removed_resource_role_binding "organizations" "${organization}" "${principal}" "${role}"
}

# Ensure that IAM binding has been removed at resource level
# Arguments:
#   $1:  The resource type (e.g. "projects", "organizations", "secrets" )
#   $2:  The id of the resource (e.g. "k8s-infra-foo", "12345")
#   $3:  The principal (e.g. "group:k8s-infra-foo@kubernetes.io")
#   $4:  The role name (e.g. "roles/foo.bar")
function _ensure_removed_resource_role_binding() {
    if [ ! $# -eq 4 -o -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
        echo "ensure_removed_project_role_binding(resource, id, principal, role) requires 4 arguments" >&2
        return 1
    fi

    local resource="${1}"
    local id="${2}"
    local principal="${3}"
    local role="${4}"

    # gcloud remove-iam-policy-binding errors if binding doesn't exist, so confirm it does
    if gcloud "${resource}" get-iam-policy "${id}" \
        --flatten="bindings[].members" \
        --format='value(bindings.role)' \
        --filter="bindings.members='${principal}' AND bindings.role='${role}'" | grep -q "${role}"; then
        gcloud \
            "${resource}" remove-iam-policy-binding "${id}" \
            --member "${principal}" \
            --role "${role}"
    fi
}
