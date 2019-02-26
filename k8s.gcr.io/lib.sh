#!/bin/sh
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

# This is a library of functions used to create GCR stuff.

function _color() {
    tput setf $1
}

function _nocolor() {
    tput sgr0
}

function color() {
    _color $1
    shift
    echo "$@"
    _nocolor
}

# The group that admins all GCR repos.
GCR_ADMINS="k8s-infra-gcr-admins@googlegroups.com"

# The service account name for the image promoter.
PROMOTER_SVCACCT="k8s-infra-gcr-promoter"

# The GCP org stuff needed to turn it all on.
GCP_ORG="758905017065" # kubernetes.io
GCP_BILLING="018801-93540E-22A20E"

# Get the GCS bucket name that backs a GCR repo.
# $1: The GCR repo (same as the GCP project name)
function gcs_bucket_for() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "gcs_bucket_for(repo, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    repo="$1"
    region="${2:-}"

    if [ -z "${region}" ]; then
        echo "gs://artifacts.${repo}.appspot.com"
    else
        echo "gs://${region}.artifacts.${repo}.appspot.com"
    fi
}

# Get the GCR host name for a region
# $1: The GCR region
function gcr_host_for() {
    if [ $# != 1 ]; then
        echo "gcr_host_for(region) requires 1 argument" >&2
        return 1
    fi
    region="$1"

    if [ -z "${region}" ]; then
        echo "gcr.io"
    else
        echo "${region}.gcr.io"
    fi
}

# Get the service account email for a given short name
# $1: The GCP project
# $2: The name
function svc_acct_for() {
    if [ $# != 2 -o -z "$1" -o -z "$2" ]; then
        echo "svc_acct_for(project, name) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    name="$2"

    echo "${name}@${project}.iam.gserviceaccount.com"
}

# Ensure that a project exists in our org.
# $1: The GCP project
function ensure_project() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "ensure_project(project) requires 1 argument" >&2
        return 1
    fi
    project="$1"

    if ! gcloud projects describe "${project}" >/dev/null 2>&1; then
        gcloud projects create "${project}" \
            --organization "${GCP_ORG}"
    else
        org=$(gcloud projects \
                describe "${project}" \
                --flatten='parent[]' \
                --format='csv[no-heading](type, id)' \
                | grep ^organization \
                | cut -f2 -d,)
        if [ "$org" != "${GCP_ORG}" ]; then
            echo "project ${project} exists, but not in our org: got ${org}" >&2
            return 2
        fi
    fi
}

# Link a project to our billing account
# $1: The GCP project
function ensure_billing() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "ensure_billing(project) requires 1 argument" >&2
        return 1
    fi
    project="$1"

    gcloud beta billing projects link "${project}" \
        --billing-account "${GCP_BILLING}"
}

# Enable an API
# $1: The GCP project
# $2: The API (e.g. containerregistry.googleapis.com)
function enable_api() {
    if [ $# != 2 -o -z "$1" -o -z "$2" ]; then
        echo "enable_api(project, api) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    api="$2"

    gcloud --project "${project}" services enable "${api}"
}

# Ensure the bucket backing the repo exists and is world-readable
# $1: The GCP project
function ensure_repo() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "ensure_repo(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    project="$1"
    region="${2:-}"

    bucket=$(gcs_bucket_for "${project}" "${region}")
    if ! gsutil ls "${bucket}" >/dev/null 2>&1; then
        host=$(gcr_host_for "${region}")
        image="ceci-nest-pas-une-image"
        dest="${host}/${project}/${image}"
        docker pull k8s.gcr.io/pause
        docker tag k8s.gcr.io/pause "${dest}"
        docker push "${dest}"
        gcloud --project "${project}" \
            container images delete --quiet "${dest}:latest"
    fi

    gsutil iam ch allUsers:objectViewer "${bucket}"
}

# Grant full privileges to GCR admins
# $1: The GCP project
function empower_gcr_admins() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "empower_gcr_admins(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    project="$1"
    region="${2:-}"
    bucket=$(gcs_bucket_for "${project}" "${region}")

    # Grant project viewer so the UI will work.
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${GCR_ADMINS}" \
        --role roles/viewer

    # Grant admins access to do admin stuff.
    gsutil iam ch \
        "group:${GCR_ADMINS}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "group:${GCR_ADMINS}:legacyBucketOwner" \
        "${bucket}"
}

# Grant write privileges to a group
# $1: The GCP project
# $2: The googlegroups group
function empower_group() {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group(project, group_name, [region]) requires 2 or 3 arguments" >&2
        return 1
    fi
    project="$1"
    group="$2"
    region="${3:-}"
    bucket=$(gcs_bucket_for "${project}" "${region}")

    gsutil iam ch \
        "group:${group}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "group:${group}:legacyBucketReader" \
        "${bucket}"
}

# Grant full privileges to the GCR promoter bot
# $1: The GCP project
function empower_promoter() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "empower_promoter(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    project="$1"
    region="${2:-}"
    bucket=$(gcs_bucket_for "${project}" "${region}")

    acct=$(svc_acct_for "${project}" "${PROMOTER_SVCACCT}")

    if ! gcloud --project "${project}" iam service-accounts describe "${acct}" >/dev/null 2>&1; then
        gcloud --project "${project}" \
            iam service-accounts create \
            "${name}" \
            --display-name="k8s-infra container image promoter"
    fi

    # Grant admins access to do admin stuff.
    gsutil iam ch \
        "serviceAccount:${acct}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "serviceAccount:${acct}:legacyBucketOwner" \
        "${bucket}"
}

# Configure bucket lifecycle for a prod repo
# $1: The GCP project
function ensure_prod_lifecycle() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "ensure_prod_lifecycle(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    project="$1"
    region="${2:-}"
    bucket=$(gcs_bucket_for "${project}" "${region}")

    # Set lifecycle policies.
    # TODO: do we want this?  It will inhibit promoter's GC, but will protect
    # against mistakenly nuking images we wanted to keep.
    #TODO: if we keep this, maybe we want to lock this (can't be overridden)?
    gsutil retention set 5y "${bucket}"
}

# Configure bucket lifecycle for a staging repo
# $1: The GCP project
function ensure_staging_lifecycle() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "ensure_staging_lifecycle(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    project="$1"
    region="${2:-}"
    bucket=$(gcs_bucket_for "${project}" "${region}")

    # Set lifecycle policies.
    gsutil retention set 30d "${bucket}"
    echo '
        {
          "rule": [
            {
              "condition": {
                "age": 30
              },
              "action": {
                "storageClass": "NEARLINE",
                "type": "SetStorageClass"
              }
            },
            {
              "condition": {
                "age": 90
              },
              "action": {
                "type": "Delete"
              }
            }
          ]
        }
        ' | gsutil lifecycle set /dev/stdin "${bucket}"
}
