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

# This is a library of functions used to create GCP stuff.

function _color() {
    tput setf "$1" || true
}

function _nocolor() {
    tput sgr0 || true
}

function color() {
    _color "$1"
    shift
    echo "$@"
    _nocolor
}

# The group that admins all GCR repos.
GCR_ADMINS="k8s-infra-artifact-admins@kubernetes.io"

# The group that admins all GCS buckets.
# We use the same group as GCR
GCS_ADMINS=$GCR_ADMINS

# The service account name for the image promoter.
PROMOTER_SVCACCT="k8s-infra-gcr-promoter"

# The service account email for Prow (not in this org for now).
PROW_SVCACCT="deployer@k8s-prow.iam.gserviceaccount.com"

# The GCP org stuff needed to turn it all on.
GCP_ORG="758905017065" # kubernetes.io
GCP_BILLING="018801-93540E-22A20E"

# Get the GCS bucket name that backs a GCR repo.
# $1: The GCR repo (same as the GCP project name)
# $2: The GCR region (optional)
function gcs_bucket_for_gcr() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "gcs_bucket_for_gcr(repo, [region]) requires 1 or 2 arguments" >&2
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
function gcr_host_for_region() {
    if [ $# != 1 ]; then
        echo "gcr_host_for_region(region) requires 1 argument" >&2
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
function svc_acct_email() {
    if [ $# != 2 -o -z "$1" -o -z "$2" ]; then
        echo "svc_acct_email(project, name) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    name="$2"

    echo "${name}@${project}.iam.gserviceaccount.com"
}

# Ensure that a project exists in our org and has fundamental configurations as
# we want them (e.g. billing).
# $1: The GCP project
function ensure_project() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "ensure_project(project) requires 1 argument" >&2
        return 1
    fi
    project="$1"

    if ! gcloud projects describe "${project}" >/dev/null 2>&1; then
        gcloud projects create "${project}" \
            --no-enable-cloud-apis \
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

# Ensure the GCS bucket backing a GCR repo exists and is world-readable.
# $1: The GCP project
# $2: The GCR region (optional)
function ensure_gcr_repo() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "ensure_gcr_repo(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    project="$1"
    region="${2:-}"

    bucket=$(gcs_bucket_for_gcr "${project}" "${region}")
    if ! gsutil ls "${bucket}" >/dev/null 2>&1; then
        host=$(gcr_host_for_region "${region}")
        image="ceci-nest-pas-une-image"
        dest="${host}/${project}/${image}"
        docker pull k8s.gcr.io/pause
        docker tag k8s.gcr.io/pause "${dest}"
        docker push "${dest}"
        gcloud --project "${project}" \
            container images delete --quiet "${dest}:latest"
    fi

    gsutil iam ch allUsers:objectViewer "${bucket}"
    gsutil bucketpolicyonly set on "${bucket}"
}

# Ensure the bucket exists and is world-readable
# $1: The GCP project
# $2: The bucket
function ensure_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_gcs_bucket(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    bucket="$2"
    location="us"

    if ! gsutil ls "${bucket}" >/dev/null 2>&1; then
      gsutil mb -p "${project}" -l "${location}" "${bucket}"
    fi
    gsutil iam ch allUsers:objectViewer "${bucket}"
    gsutil bucketpolicyonly set on "${bucket}"
}

# Sets the web policy on the bucket, including a default index.html page
# $1: The bucket
function ensure_gcs_web_policy() {
    if [ $# -lt 1 -o -z "$1" ]; then
        echo "ensure_gcs_web_policy(bucket) requires 1 argument" >&2
        return 1
    fi
    bucket="$1"

    gsutil web set -m index.html "${bucket}"
}

# Copies any static content into the bucket
# $1: The bucket
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

# Grant project viewer privileges to a principal
# $1: The GCP project
# $2: The group email
function empower_group_as_viewer() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_as_viewer(project, group) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    group="$2"

    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${group}" \
        --role roles/viewer
}

# Grant privileges to prow in a staging project
# $1: The GCP project
# $2: The GCS scratch bucket
function empower_prow() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_prow(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    bucket="$2"

    # Allow prow to trigger builds.
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "serviceAccount:${PROW_SVCACCT}" \
        --role roles/cloudbuild.builds.builder

    # Allow prow to push source and access build logs.
    gsutil iam ch \
        "serviceAccount:${PROW_SVCACCT}:objectCreator" \
        "${bucket}"
    gsutil iam ch \
        "serviceAccount:${PROW_SVCACCT}:objectViewer" \
        "${bucket}"
}

# Grant full privileges to GCR admins
# $1: The GCP project
# $2: The GCR region (optional)
function empower_gcr_admins() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "empower_gcr_admins(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    project="$1"
    region="${2:-}"
    bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    # Grant project viewer so the UI will work.
    empower_group_as_viewer "${project}" "${GCR_ADMINS}"

    # Grant admins access to do admin stuff.
    gsutil iam ch \
        "group:${GCR_ADMINS}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "group:${GCR_ADMINS}:legacyBucketOwner" \
        "${bucket}"
}

# Grant full privileges to GCS admins
# $1: The GCP project
# $2: The bucket
function empower_gcs_admins() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_gcs_admins(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    project="${1}"
    bucket="${2}"

    # Grant project viewer so the UI will work.
    empower_group_as_viewer "${project}" "${GCS_ADMINS}"

    # Grant admins access to do admin stuff.
    gsutil iam ch \
        "group:${GCS_ADMINS}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "group:${GCS_ADMINS}:legacyBucketOwner" \
        "${bucket}"
}

# Grant GCR write privileges to a group
# $1: The GCP project
# $2: The googlegroups group
# $3: The GCR region (optional)
function empower_group_to_gcr() {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_to_gcr(project, group_name, [region]) requires 2 or 3 arguments" >&2
        return 1
    fi
    project="$1"
    group="$2"
    region="${3:-}"
    bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    gsutil iam ch \
        "group:${group}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "group:${group}:legacyBucketReader" \
        "${bucket}"
}

# Grant write privileges on a bucket to a group
# $1: The googlegroups group
# $2: The bucket
function empower_group_to_gcs_bucket() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_to_gcs_bucket(group_name, bucket) requires 2 arguments" >&2
        return 1
    fi
    group="$1"
    bucket="$2"

    gsutil iam ch \
        "group:${group}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "group:${group}:legacyBucketReader" \
        "${bucket}"
}

# Grant full privileges to the GCR promoter bot
# $1: The GCP project
# $2: The GCR region (optional)
function empower_artifact_promoter() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "empower_artifact_promoter(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    project="$1"
    region="${2:-}"

    acct=$(svc_acct_email "${project}" "${PROMOTER_SVCACCT}")

    if ! gcloud --project "${project}" iam service-accounts describe "${acct}" >/dev/null 2>&1; then
        gcloud --project "${project}" \
            iam service-accounts create \
            "${PROMOTER_SVCACCT}" \
            --display-name="k8s-infra container image promoter"
    fi

    empower_service_account_to_artifacts "${acct}" "${project}" "${region}"
}

# Grant artifact privileges to a service account in a project/region.
# $1: The GCP service account email
# $2: The GCP project
# $3: The GCR region (optional)
function empower_service_account_to_artifacts () {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "empower_service_account_to_artifacts(acct, project, [region]) requires 2 or 3 arguments" >&2
        return 1
    fi
    acct="$1"
    project="$2"
    region="${3:-}"
    bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    # Grant admins access to do admin stuff.
    gsutil iam ch \
        "serviceAccount:${acct}:objectAdmin" \
        "${bucket}"
    gsutil iam ch \
        "serviceAccount:${acct}:legacyBucketOwner" \
        "${bucket}"
}

# Ensure the bucket retention policy is set
# $1: The GCS bucket
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
# $1: The GCS bucket
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

# Create a service account
# $1: The GCP project
# $2: The account name (e.g. "foo-manager")
# $3: The account display-name (e.g. "Manages all foo")
function ensure_service_account() {
    if [ $# != 3 -o -z "$1" -o -z "$2" -o -x "$3" ]; then
        echo "ensure_service_account(project, name, display_name) requires 3 arguments" >&2
        return 1
    fi
    project="$1"
    name="$2"
    display_name="$3"

    acct=$(svc_acct_email "${project}" "${name}")

    if ! gcloud --project "${project}" iam service-accounts describe "${acct}" >/dev/null 2>&1; then
        gcloud --project "${project}" \
            iam service-accounts create \
            "${name}" \
            --display-name="${display_name}"
    fi
}
