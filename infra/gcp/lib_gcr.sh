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

# GCR utility functions
#
# This is intended to be very general-purpose and "low-level".  Higher-level
# policy does not belong here.
#
# This MUST NOT be used directly. Source it via lib.sh instead.

# Get the GCS bucket name that backs a GCR repo.
# $1: The GCR repo (same as the GCP project name)
# $2: The GCR region (optional)
function gcs_bucket_for_gcr() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "gcs_bucket_for_gcr(repo, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    local repo="$1"
    local region="${2:-}"

    if [ -z "${region}" ]; then
        echo "gs://artifacts.${repo}.appspot.com"
    else
        echo "gs://${region}.artifacts.${repo}.appspot.com"
    fi
}

# Get the GCR host name for a region
# $1: The GCR region
function gcr_host_for_region() {
    if [ $# != 1 ]; then
        echo "gcr_host_for_region(region) requires 1 argument" >&2
        return 1
    fi
    local region="$1"

    if [ -z "${region}" ]; then
        echo "gcr.io"
    else
        echo "${region}.gcr.io"
    fi
}

# Ensure the GCS bucket backing a GCR repo exists and is world-readable.
# $1: The GCP project
# $2: The GCR region (optional)
function ensure_gcr_repo() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "ensure_gcr_repo(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local region="${2:-}"

    local bucket=$(gcs_bucket_for_gcr "${project}" "${region}")
    if ! gsutil ls "${bucket}" >/dev/null 2>&1; then
        local host=$(gcr_host_for_region "${region}")
        local image="ceci-nest-pas-une-image"
        local dest="${host}/${project}/${image}"
        docker pull k8s.gcr.io/pause
        docker tag k8s.gcr.io/pause "${dest}"
        docker push "${dest}"
        gcloud --project "${project}" \
            container images delete --quiet "${dest}:latest"
    fi

    gsutil iam ch allUsers:objectViewer "${bucket}"
    gsutil bucketpolicyonly set on "${bucket}"
}

# Grant write privileges on a GCR to a group
# $1: The googlegroups group email
# $2: The GCP project
# $3: The GCR region (optional)
function empower_group_to_write_gcr() {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_to_write_gcr(group_name, project, [region]) requires 2 or 3 arguments" >&2
        return 1
    fi
    local group="$1"
    local project="$2"
    local region="${3:-}"
    local bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    empower_group_to_write_gcs_bucket "${group}" "${bucket}"
}

# Grant admin privileges on a GCR to a group
# $1: The googlegroups group email
# $2: The GCP project
# $3: The GCR region (optional)
function empower_group_to_admin_gcr() {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_to_admin_gcr(group_name, project, [region]) requires 2 or 3 arguments" >&2
        return 1
    fi
    local group="$1"
    local project="$2"
    local region="${3:-}"
    local bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    empower_group_to_admin_gcs_bucket "${group}" "${bucket}"
}

# Grant GCR write privileges to a service account in a project/region.
# $1: The GCP service account email
# $2: The GCP project
# $3: The GCR region (optional)
function empower_svcacct_to_write_gcr () {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "empower_svcacct_to_write_gcr(acct, project, [region]) requires 2 or 3 arguments" >&2
        return 1
    fi
    local acct="$1"
    local project="$2"
    local region="${3:-}"
    local bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    empower_svcacct_to_write_gcs_bucket "${acct}" "${bucket}"
}

# Grant GCR admin privileges to a service account in a project/region.
# $1: The GCP service account email
# $2: The GCP project
# $3: The GCR region (optional)
function empower_svcacct_to_admin_gcr () {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "empower_svcacct_to_admin_gcr(acct, project, [region]) requires 2 or 3 arguments" >&2
        return 1
    fi
    local acct="$1"
    local project="$2"
    local region="${3:-}"
    local bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    empower_svcacct_to_admin_gcs_bucket "${acct}" "${bucket}"
}
