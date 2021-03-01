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

readonly tmp_dir=$(mktemp -d "/tmp/k8sinfra-lib_iam.XXXXX")
trap 'rm -rf "${tmp_dir}"' EXIT

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

# Ensure that custom IAM role exists in organization and in sync with definition in file
# Arguments:
#   $1:  The role name (e.g. "foo.barrer")
#   $2:  The file (e.g. "/path/to/file.yaml")
function ensure_custom_org_iam_role_from_file() {
    if [ ! $# -eq 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_custom_org_iam_role_from_file(name, file) requires 2 arguments" >&2
        return 1
    fi

    local organization="${GCP_ORG}"
    local name="${1}"
    local file="${2}"

    _ensure_custom_iam_role_from_file "organization" "${organization}" "${name}" "${file}"
}

# Ensure that custom IAM role exists in project and in sync with definition in file
# Arguments:
#   $1:  The id of the project (e.g. "k8s-infra-foo")
#   $2:  The role name (e.g. "foo.barrer")
#   $3:  The file (e.g. "/path/to/file.yaml")
function ensure_custom_project_iam_role_from_file() {
    if [ ! $# -eq 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "ensure_custom_project_iam_role_from_file(project, name, file) requires 3 arguments" >&2
        return 1
    fi

    local project="${1}"
    local name="${2}"
    local file="${3}"

    _ensure_custom_iam_role_from_file "project" "${project}" "${name}" "${file}"
}

# Ensure that custom IAM role has been removed from organization
# Arguments:
#   $1:  The role name (e.g. "foo.barrer")
function ensure_removed_custom_org_iam_role() {
    if [ ! $# -eq 1 -o -z "$1" ]; then
        echo "ensure_removed_custom_org_iam_role(name) requires 1 arguments" >&2
        return 1
    fi

    local organization="${GCP_ORG}"
    local name="${1}"

    _ensure_removed_custom_iam_role "organization" "${organization}" "${name}"
}

# Ensure that custom IAM role has been removed from project
# Arguments:
#   $1:  The id of the project (e.g. "k8s-infra-foo")
#   $2:  The role name (e.g. "foo.barrer")
function ensure_removed_custom_project_iam_role() {
    if [ ! $# -eq 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_removed_custom_project_iam_role(project, name) requires 2 arguments" >&2
        return 1
    fi

    local project="${1}"
    local name="${2}"

    _ensure_removed_custom_iam_role "project" "${project}" "${name}"
}

# Return the full name of a custom IAM role defined at the org level
# Arguments:
#   $1:  The role name (e.g. "foo.barrer")
function custom_org_role_name() {
    if [ ! $# -eq 1 -o -z "$1" ]; then
        echo "custom_org_role_name(name) requires 1 arguments" >&2
        return 1
    fi

    local name="${1}"

    # the equivalent gcloud command takes longer and may require more privileges
    # gcloud iam roles describe --organization ${organization} ${name} --format='value(name)'
    echo "organizations/${GCP_ORG}/roles/${name}"
}

# Return the full name of a custom IAM role defined at the org level
# Arguments:
#   $1:  The is of the project (e.g. "k8s-infra-foo")
#   $2:  The role name (e.g. "foo.barrer")
function custom_project_role_name() {
    if [ ! $# -eq 2 -o -z "$1" -o -z "$2" ]; then
        echo "custom_project_role_name(project, name) requires 2 arguments" >&2
        return 1
    fi

    local project="${1}"
    local name="${2}"

    # the equivalent gcloud command takes longer and may require more privileges
    # gcloud iam roles describe --projects ${project} ${name} --format='value(name)'
    echo "projects/${project}/roles/${name}"
}

# Ensure that IAM binding is present for organization
# Arguments:
#   $1:  The role name (e.g. "foo.barrer")
#   $2:  The file (e.g. "/path/to/file.yaml")
function ensure_org_role_binding() {
    if [ ! $# -eq 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_org_role_binding(principal, role) requires 2 arguments" >&2
        return 1
    fi

    local organization="${GCP_ORG}"
    local principal="${1}"
    local role="${2}"

    _ensure_resource_role_binding "organizations" "${organization}" "${principal}" "${role}"
}

# Ensure that IAM binding is present for project
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

    _ensure_resource_role_binding "projects" "${project}" "${principal}" "${role}"
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

# Ensure that custom IAM role exists in scope and in sync with definition in file
# Arguments:
#   $1:  The scope of the role (e.g. "organization", "project")
#   $2:  The id of the scope (e.g. "12345819", "k8s-infra-foo")
#   $3:  The role name (e.g. "foo.barrer")
#   $4:  The file (e.g. "/path/to/file.yaml")
function _ensure_custom_iam_role_from_file() {
    if [ ! $# -eq 4 -o -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
        echo "_ensure_custom_iam_role_from_file(scope, id, name, file) requires 4 arguments" >&2
        return 1
    fi

    local scope="${1}"
    local id="${2}"
    local name="${3}"
    local file="${4}"
    case "${scope}" in
      organization | project ) ;;
      * )
        echo "_ensure_custom_iam_role_from_file(scope, id, name, file) scope must 'organization' or 'project'" >&2
        return 1
        ;;
    esac

    local scope_flag="--${scope} ${id}"

    local before="${tmp_dir}/custom-role.before.yaml"
    local ready="${tmp_dir}/custom-role.ready.yaml"
    local after="${tmp_dir}/custom-role.after.yaml"

    # detect if we should create or update and dump role; silently ignore error
    verb="update"
    if ! (gcloud iam roles describe ${scope_flag} "${name}" | yq -Y 'del(.etag)' >"${before}") >/dev/null 2>&1; then
        verb="create"
    fi

    # deleted roles can be undeleted within 7 days; after that must wait 30 days to create a role with same id
    # ref: https://cloud.google.com/iam/docs/creating-custom-roles#deleting-custom-role
    if <"${before}" grep -q "^deleted: true"; then
        gcloud iam roles undelete ${scope_flag} "${name}"
    fi

    # name is foo.bar, but gcloud wants scopes/id/role/foo.bar in the file
    local full_name="${scope}s/${id}/roles/${name}"
    <"${file}" sed -e "s|^name: ${name}|name: ${full_name}|" >"${ready}"
    gcloud iam roles "${verb}" ${scope_flag} "${name}" --file "${ready}" | yq -Y 'del(.etag)' > "${after}"

    # if they differ, ignore the error
    diff -u "${before}" "${after}" || true
}

# Ensure that custom IAM role exists in scope and in sync with definition in file
# Arguments:
#   $1:  The scope of the role (e.g. "organization", "project")
#   $2:  The id of the scope (e.g. "12345819", "k8s-infra-foo")
#   $3:  The role name (e.g. "foo.barrer")
function _ensure_removed_custom_iam_role() {
    if [ ! $# -eq 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "_ensure_removed_custom_iam_role(scope, id, name) requires 3 arguments" >&2
        return 1
    fi

    local scope="${1}"
    local id="${2}"
    local name="${3}"
    case "${scope}" in
      organization | project ) ;;
      * )
        echo "_ensure_removed_custom_iam_role(scope, id, name) scope must 'organization' or 'project'" >&2
        return 1
        ;;
    esac

    local scope_flag="--${scope} ${id}"

    local before="${tmp_dir}/iam-bind.before.txt"

    # gcloud iam roles delete errors if role doesn't exist, so confirm it does
    if ! gcloud iam roles describe ${scope_flag} ${name} --format="value(deleted)" > "${before}"; then
        # not found, or can't see... no point in continuing
        return
    fi
    # gcloud iam roles delete errors if role has already been deleted, so confirm it has not
    if [ "$(cat "${before}")" == "True" ]; then
        # already deleted, nothing to do
        return
    fi
    gcloud iam roles delete ${scope_flag} "${name}"
}

# Ensure that IAM binding is present for resource
# Arguments:
#   $1:  The resource type (e.g. "projects", "organizations", "secrets" )
#   $2:  The id of the resource (e.g. "k8s-infra-foo", "12345")
#   $3:  The principal (e.g. "group:k8s-infra-foo@kubernetes.io")
#   $4:  The role name (e.g. "roles/foo.bar")
function _ensure_resource_role_binding() {
    if [ ! $# -eq 4 -o -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
        echo "_ensure_resource_role_binding(resource, id, principal, role) requires 4 arguments" >&2
        return 1
    fi

    local resource="${1}"
    local id="${2}"
    local principal="${3}"
    local role="${4}"

    local before="${tmp_dir}/iam-bind.before.yaml"
    local after="${tmp_dir}/iam-bind.after.yaml"

    # gcloud add-iam-policy-binding will not error on adding a duplicate binding
    # TODO: that said, it is annoying to see lots of "updated iam policy for X" when nothing changed,
    #       so consider avoiding the call
    gcloud "${resource}" get-iam-policy "${id}" | yq -Y 'del(.etag)' > "${before}"
    # add the binding
    gcloud \
        "${resource}" add-iam-policy-binding "${id}" \
        --member "${principal}" \
        --role "${role}" | \
        yq -Y 'del(.etag)' > "${after}"
    # if they differ, ignore the error
    diff -u "${before}" "${after}" || true
}

# Ensure that IAM binding has been removed from resource
# Arguments:
#   $1:  The resource type (e.g. "projects", "organizations", "secrets" )
#   $2:  The id of the resource (e.g. "k8s-infra-foo", "12345")
#   $3:  The principal (e.g. "group:k8s-infra-foo@kubernetes.io")
#   $4:  The role name (e.g. "roles/foo.bar")
function _ensure_removed_resource_role_binding() {
    if [ ! $# -eq 4 -o -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
        echo "_ensure_removed_resource_role_binding(resource, id, principal, role) requires 4 arguments" >&2
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
