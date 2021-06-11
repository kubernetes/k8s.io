#!/usr/bin/env bash

# Copyright 2020 The Kubernetes Authors.
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

# GCS utility functions
#
# This is intended to be very general-purpose and "low-level".  Higher-level
# policy does not belong here.
#
# This MUST NOT be used directly. Source it via lib.sh instead.

# Ensure that a bucket exists
# $1: The GCP project
# $2: The bucket (e.g. gs://bucket-name)
function _ensure_gcs_bucket() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "_ensure_gcs_bucket(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local bucket="$2"
    local location="us"

    if ! gsutil ls "${bucket}" >/dev/null 2>&1; then
        gsutil mb -p "${project}" -l "${location}" "${bucket}"
    fi
    if ! gsutil bucketpolicyonly get "${bucket}" | grep -q "Enabled: True"; then
        gsutil bucketpolicyonly set on "${bucket}"
    fi
}

# Ensure the bucket exists and is world-readable
# $1: The GCP project
# $2: The bucket (e.g. gs://bucket-name)
function ensure_public_gcs_bucket() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "ensure_public_gcs_bucket(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local bucket="$2"

    _ensure_gcs_bucket "${project}" "${bucket}"
    ensure_gcs_role_binding "${bucket}" "allUsers" "objectViewer"
}

# Ensure the bucket exists and is NOT world-accessible
# $1: The GCP project
# $2: The bucket (e.g. gs://bucket-name)
function ensure_private_gcs_bucket() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "ensure_private_gcs_bucket(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local bucket="$2"

    _ensure_gcs_bucket "${project}" "${bucket}"
    ensure_removed_gcs_role_binding "${bucket}" "allUsers" "objectViewer"
    # roles/storage.legacyBucketOwner contains storage.buckets.setIamPolicy,
    # but not storage.objects.get. This means someone with roles/editor on the
    # project could grant themselves access to read bucket contents that they
    # aren't supposed to be able to read.
    #
    # Given that roles/editor has no *.setIamPolicy permissions for other
    # service resources, this seems like a security gap that should be closed.
    #
    # Ideally we would do this in _ensure_gcs_bucket. However, removing this
    # role means removing other (possibly needed) permissions that may be used
    # by GCP service agent service accounts (e.g. App Engine, GCR, GCE):
    # - storage.buckets.get
    # - storage.multipartUploads.(abort|create|list|listParts)
    # - storage.objects.(create|delete|list)
    #
    # So until we have time to research what buckets those service agents
    # specifically need access to, we'll leave them alone and constrain this
    # policy to "private" gcs buckets that are currently only used by humans
    # to store terraform state containing potentially sensitive info
    ensure_removed_gcs_role_binding "${bucket}" "projectEditor:${project}" "legacyBucketOwner"
}

# Sets the web policy on the bucket, including a default index.html page
# $1: The bucket (e.g. gs://bucket-name)
function ensure_gcs_web_policy() {
    if [ $# -lt 1 ] || [ -z "$1" ]; then
        echo "ensure_gcs_web_policy(bucket) requires 1 argument" >&2
        return 1
    fi
    local bucket="$1"

    gsutil web set -m index.html "${bucket}"
}

# Copies any static content into the bucket
# $1: The bucket (e.g. gs://bucket-name)
# $2: The source directory
function upload_gcs_static_content() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "upload_gcs_static_content(bucket, dir) requires 2 arguments" >&2
        return 1
    fi
    local bucket="$1"
    local srcdir="$2"

    # Checksum data to avoid no-op syncs.
    gsutil rsync -c "${srcdir}" "${bucket}"
}

# Ensure the bucket retention policy is set
# $1: The GCS bucket (e.g. gs://bucket-name)
# $2: The retention
function ensure_gcs_bucket_retention() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "ensure_gcs_bucket_retention(bucket, retention) requires 2 arguments" >&2
        return 1
    fi
    local bucket="$1"
    local retention="$2"

    gsutil retention set "${retention}" "${bucket}"
}

# Ensure the bucket auto-deletion policy is set
# $1: The GCS bucket (e.g. gs://bucket-name)
# $2: The auto-deletion policy
function ensure_gcs_bucket_auto_deletion() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "ensure_gcs_bucket_auto_deletion(bucket, auto_delettion_days) requires 2 arguments" >&2
        return 1
    fi
    local bucket="$1"
    local auto_deletion_days="$2"

    local intent="${TMPDIR}/gcs-lifecycle.intent.yaml"
    local before="${TMPDIR}/gcs-lifecycle.before.yaml"
    local after="${TMPDIR}/gcs-lifecycle.after.yaml"

    echo "{\"rule\": [{\"action\": {\"type\": \"Delete\"}, \"condition\": {\"age\": ${auto_deletion_days}}}]}" > "${intent}"
    gsutil lifecycle get "${bucket}"> "${before}"
    if ! diff "${intent}" "${before}"; then
        gsutil lifecycle set "${intent}" "${bucket}"
        gsutil lifecycle get "${bucket}" > "${after}"
        diff_colorized "${before}" "${after}"
    fi
}

# Grant write privileges on a bucket to a principal
# $1: The principal (group:<g> or serviceAccount:<s> or ...)
# $2: The bucket (e.g. gs://bucket-name)
function _empower_principal_to_write_gcs_bucket() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "_empower_principal_to_write_gcs_bucket(principal, bucket) requires 2 arguments" >&2
        return 1
    fi
    local principal="$1"
    local bucket="$2"

    ensure_gcs_role_binding "${bucket}" "${principal}" "objectAdmin"
    ensure_gcs_role_binding "${bucket}" "${principal}" "legacyBucketWriter"
}

# Grant admin privileges on a bucket to a principal
# $1: The principal (group:<g> or serviceAccount:<s> or ...)
# $2: The bucket (e.g. gs://bucket-name)
function _empower_principal_to_admin_gcs_bucket() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "_empower_principal_to_admin_gcs_bucket(principal, bucket) requires 2 arguments" >&2
        return 1
    fi
    local principal="$1"
    local bucket="$2"

    ensure_gcs_role_binding "${bucket}" "${principal}" "objectAdmin"
    ensure_gcs_role_binding "${bucket}" "${principal}" "legacyBucketOwner"
}

# Ensure that IAM binding is present for the given gcs bucket
# Arguments:
#   $1:  The bucket (e.g. "gs://k8s-infra-foo"
#   $2:  The principal (e.g. "group:k8s-infra-foo@kubernetes.io", "allUsers", etc.)
#   $3:  The role name (e.g. "objectAdmin", "legacyBucketOwner", etc.)
ensure_gcs_role_binding() {
    if [ ! $# -eq 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "ensure_gcs_role_binding(bucket, principal, role) requires 3 arguments" >&2
        return 1
    fi

    local bucket="${1}"
    local principal="${2}"
    local role="${3}"

    # use json for gsutil iam set, yaml for easier diffing
    local before_json="${TMPDIR}/gsutil-iam-get.before.json"
    local after_json="${TMPDIR}/gsutil-iam-get.after.json"
    local before_yaml="${TMPDIR}/gcs-role-binding.before.yaml"
    local after_yaml="${TMPDIR}/gcs-role-binding.after.yaml"

    gsutil iam get "${bucket}" > "${before_json}"
    <"${before_json}" yq -y | _format_iam_policy > "${before_yaml}"

    # Avoid calling `gsutil iam set` if we can, to reduce output noise
    if ! <"${before_yaml}" yq --exit-status \
        ".[] | select(contains({role: \"${role}\", member: \"${principal}\"}))" \
        >/dev/null; then

        # add the binding, then merge with existing bindings
        # shellcheck disable=SC2016 # jq uses $foo for variables
        <"${before_json}" yq --arg role "${role}" --arg principal "${principal}" \
          '.bindings |= (
              . + [{
                members: [$principal],
                role: ("roles/storage." + $role)
              }]
              | group_by(.role)
              | map({
                  members: map(.members) | flatten | unique,
                  role: .[0].role
                })
            )' > "${after_json}"

        gsutil iam set "${after_json}" "${bucket}"
        <"${after_json}" yq -y | _format_iam_policy > "${after_yaml}"

        diff_colorized "${before_yaml}" "${after_yaml}"
    fi
}

# Ensure that IAM binding is removed for the given gcs bucket
# Arguments:
#   $1:  The bucket (e.g. "gs://k8s-infra-foo"
#   $2:  The principal (e.g. "group:k8s-infra-foo@kubernetes.io", "allUsers", etc.)
#   $3:  The role name (e.g. "objectAdmin", "legacyBucketOwner", etc.)
ensure_removed_gcs_role_binding() {
    if [ ! $# -eq 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "ensure_removed_gcs_role_binding(bucket, principal, role) requires 3 arguments" >&2
        return 1
    fi

    local bucket="${1}"
    local principal="${2}"
    local role="${3}"

    # use json for gsutil iam set, yaml for easier diffing
    local before_json="${TMPDIR}/gsutil-iam-get.before.json"
    local after_json="${TMPDIR}/gsutil-iam-get.after.json"
    local before_yaml="${TMPDIR}/gcs-role-binding.before.yaml"
    local after_yaml="${TMPDIR}/gcs-role-binding.after.yaml"

    gsutil iam get "${bucket}" > "${before_json}"
    <"${before_json}" yq -y | _format_iam_policy > "${before_yaml}"

    # Avoid calling `gsutil iam set` if we can, to reduce output noise
    if <"${before_yaml}" yq --exit-status \
        ".[] | select(contains({role: \"${role}\", member: \"${principal}\"}))" \
        >/dev/null; then

        # remove member from role if it exists; gcs deletes bindings with no
        # members, so we don't need to bother pruning them here
        # shellcheck disable=SC2016 # jq uses $foo for variables
        <"${before_json}" yq --arg role "${role}" --arg principal "${principal}" \
          '.bindings |= map(
              if .role == ("roles/storage." + $role) then
                .members -= [$principal]
              else
                .
              end
            )' > "${after_json}"

        gsutil iam set "${after_json}" "${bucket}"
        <"${after_json}" yq -y | _format_iam_policy > "${after_yaml}"

        diff_colorized "${before_yaml}" "${after_yaml}"
    fi
}

# Grant write privileges on a bucket to a group
# $1: The googlegroups group email
# $2: The bucket (e.g. gs://bucket-name)
function empower_group_to_write_gcs_bucket() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_group_to_write_gcs_bucket(group_email, bucket) requires 2 arguments" >&2
        return 1
    fi
    local group="$1"
    local bucket="$2"

    _empower_principal_to_write_gcs_bucket "group:${group}" "${bucket}"
}

# Grant admin privileges on a bucket to a group
# $1: The googlegroups group email
# $2: The bucket (e.g. gs://bucket-name)
function empower_group_to_admin_gcs_bucket() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_group_to_admin_gcs_bucket(group_email, bucket) requires 2 arguments" >&2
        return 1
    fi
    local group="$1"
    local bucket="$2"

    _empower_principal_to_admin_gcs_bucket "group:${group}" "${bucket}"
}

# Grant write privileges on a bucket to a service account
# $1: The service account email
# $2: The bucket (e.g. gs://bucket-name)
function empower_svcacct_to_write_gcs_bucket() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_svcacct_to_write_gcs_bucket(svcacct_email, bucket) requires 2 arguments" >&2
        return 1
    fi
    local svcacct="$1"
    local bucket="$2"

    _empower_principal_to_write_gcs_bucket "serviceAccount:${svcacct}" "${bucket}"
}

# Grant admin privileges on a bucket to a service account
# $1: The service account email
# $2: The bucket (e.g. gs://bucket-name)
function empower_svcacct_to_admin_gcs_bucket() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_svcacct_to_admin_gcs_bucket(svcacct_email, bucket) requires 2 arguments" >&2
        return 1
    fi
    local svcacct="$1"
    local bucket="$2"

    _empower_principal_to_admin_gcs_bucket "serviceAccount:${svcacct}" "${bucket}"
}
