#!/usr/bin/env bash
#
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
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "_ensure_gcs_bucket(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    bucket="$2"
    location="us"

    if ! gsutil ls "${bucket}" >/dev/null 2>&1; then
      gsutil mb -p "${project}" -l "${location}" "${bucket}"
    fi
    gsutil bucketpolicyonly set on "${bucket}"
}

# Ensure the bucket exists and is world-readable
# $1: The GCP project
# $2: The bucket (e.g. gs://bucket-name)
function ensure_public_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_public_gcs_bucket(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    bucket="$2"

    _ensure_gcs_bucket "${project}" "${bucket}"
    gsutil iam ch allUsers:objectViewer "${bucket}"
}

# Ensure the bucket exists and is NOT world-accessible
# $1: The GCP project
# $2: The bucket (e.g. gs://bucket-name)
function ensure_private_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_private_gcs_bucket(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    bucket="$2"

    _ensure_gcs_bucket "${project}" "${bucket}"
    gsutil iam ch -d allUsers "${bucket}"
}

# Sets the web policy on the bucket, including a default index.html page
# $1: The bucket (e.g. gs://bucket-name)
function ensure_gcs_web_policy() {
    if [ $# -lt 1 -o -z "$1" ]; then
        echo "ensure_gcs_web_policy(bucket) requires 1 argument" >&2
        return 1
    fi
    bucket="$1"

    gsutil web set -m index.html "${bucket}"
}

# Copies any static content into the bucket
# $1: The bucket (e.g. gs://bucket-name)
# $2: The source directory
function upload_gcs_static_content() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "upload_gcs_static_content(bucket, dir) requires 2 arguments" >&2
        return 1
    fi
    bucket="$1"
    srcdir="$2"

    # Checksum data to avoid no-op syncs.
    gsutil rsync -c "${srcdir}" "${bucket}"
}

# Ensure the bucket retention policy is set
# $1: The GCS bucket (e.g. gs://bucket-name)
# $2: The retention
function ensure_gcs_bucket_retention() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_gcs_bucket_retention(bucket, retention) requires 2 arguments" >&2
        return 1
    fi
    bucket="$1"
    retention="$2"

    gsutil retention set "${retention}" "${bucket}"
}

# Ensure the bucket auto-deletion policy is set
# $1: The GCS bucket (e.g. gs://bucket-name)
# $2: The auto-deletion policy
function ensure_gcs_bucket_auto_deletion() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_gcs_bucket_auto_deletion(bucket, auto_delettion_days) requires 2 arguments" >&2
        return 1
    fi
    bucket="$1"
    auto_deletion_days="$2"

    echo "
        {
          \"rule\": [
            {
              \"condition\": {
                \"age\": ${auto_deletion_days}
              },
              \"action\": {
                \"type\": \"Delete\"
              }
            }
          ]
        }
    " | gsutil lifecycle set /dev/stdin "${bucket}"
}

# Grant write privileges on a bucket to a principal
# $1: The principal (group:<g> or serviceAccount:<s> or ...)
# $2: The bucket (e.g. gs://bucket-name)
function _empower_principal_to_write_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "_empower_principal_to_write_gcs_bucket(principal, bucket) requires 2 arguments" >&2
        return 1
    fi
    principal="$1"
    bucket="$2"

    gsutil iam ch \
        "${principal}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "${principal}:legacyBucketReader" \
        "${bucket}"
}

# Grant admin privileges on a bucket to a principal
# $1: The principal (group:<g> or serviceAccount:<s> or ...)
# $2: The bucket (e.g. gs://bucket-name)
function _empower_principal_to_admin_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "_empower_principal_to_admin_gcs_bucket(principal, bucket) requires 2 arguments" >&2
        return 1
    fi
    principal="$1"
    bucket="$2"

    gsutil iam ch \
        "${principal}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "${principal}:legacyBucketOwner" \
        "${bucket}"
}

# Grant write privileges on a bucket to a group
# $1: The googlegroups group email
# $2: The bucket (e.g. gs://bucket-name)
function empower_group_to_write_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_to_write_gcs_bucket(group_email, bucket) requires 2 arguments" >&2
        return 1
    fi
    group="$1"
    bucket="$2"

    _empower_principal_to_write_gcs_bucket "group:${group}" "${bucket}"
}

# Grant admin privileges on a bucket to a group
# $1: The googlegroups group email
# $2: The bucket (e.g. gs://bucket-name)
function empower_group_to_admin_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_to_admin_gcs_bucket(group_email, bucket) requires 2 arguments" >&2
        return 1
    fi
    group="$1"
    bucket="$2"

    _empower_principal_to_admin_gcs_bucket "group:${group}" "${bucket}"
}

# Grant write privileges on a bucket to a service account
# $1: The service account email
# $2: The bucket (e.g. gs://bucket-name)
function empower_svcacct_to_write_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_svcacct_to_write_gcs_bucket(svcacct_email, bucket) requires 2 arguments" >&2
        return 1
    fi
    svcacct="$1"
    bucket="$2"

    _empower_principal_to_write_gcs_bucket "serviceAccount:${svcacct}" "${bucket}"
}

# Grant admin privileges on a bucket to a service account
# $1: The service account email
# $2: The bucket (e.g. gs://bucket-name)
function empower_svcacct_to_admin_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_svcacct_to_admin_gcs_bucket(svcacct_email, bucket) requires 2 arguments" >&2
        return 1
    fi
    svcacct="$1"
    bucket="$2"

    _empower_principal_to_admin_gcs_bucket "serviceAccount:${svcacct}" "${bucket}"
}
