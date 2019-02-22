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

# The GCP org stuff needed to turn it all on.
GCP_ORG="758905017065" # kubernetes.io
GCP_BILLING="018801-93540E-22A20E"

# Get the GCS bucket name that backs a GCR repo.
# $1: The GCR repo (same as the GCP project name)
function gcs_bucket_for() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "gcs_bucket_for(repo_name) requires 1 argument" > /dev/stderr
        return 1
    fi
    repo="$1"

    echo "gs://artifacts.${repo}.appspot.com"
}

# Get the service account email for a given short name
# $1: The GCP project
# $2: The name
function svc_acct_for() {
    if [ $# != 2 -o -z "$1" -o -z "$2" ]; then
        echo "svc_acct_for(project, name) requires 2 arguments" > /dev/stderr
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
        echo "ensure_project(proj_name) requires 1 argument" > /dev/stderr
        return 1
    fi
    project="$1"

    if ! gcloud projects describe "${project}" >/dev/null 2>&1; then
        gcloud projects create "${project}" \
            --organization "${GCP_ORG}"
    else
        o=$(gcloud projects \
                describe "${project}" \
                --flatten='parent[]' \
                --format='csv[no-heading](type, id)' \
                | grep ^organization \
                | cut -f2 -d,)
        if [ "$o" != "${GCP_ORG}" ]; then
            echo "project ${project} exists, but not in our org: got ${o}" > /dev/stderr
            return 2
        fi
    fi
}

# Link a project to our billing account
# $1: The GCP project
function ensure_billing() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "ensure_billing(proj_name) requires 1 argument" > /dev/stderr
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
        echo "enable_api(proj_name, api) requires 2 arguments" > /dev/stderr
        return 1
    fi
    project="$1"
    api="$2"

    gcloud --project "${project}" services enable "${api}"
}

# Ensure the bucket backing the repo exists and is world-readable
# $1: The GCP project
function ensure_repo() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "ensure_repo(proj_name) requires 1 argument" > /dev/stderr
        return 1
    fi
    project="$1"

    if ! gsutil ls $(gcs_bucket_for ${project}) >/dev/null 2>&1; then
        phony="ceci-nest-pas-une-image"
        docker pull k8s.gcr.io/pause
        docker tag k8s.gcr.io/pause "gcr.io/${project}/${phony}"
        docker push "gcr.io/${project}/${phony}"
        gcloud --project "${project}" \
            container images delete --quiet "gcr.io/${project}/${phony}:latest"
    fi

    gsutil iam ch allUsers:objectViewer $(gcs_bucket_for ${project})
}

# Grant full privileges to GCR admins
# $1: The GCP project
function empower_gcr_admins() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "empower_gcr_admins(proj_name) requires 1 argument" > /dev/stderr
        return 1
    fi
    project="$1"

    # Grant project viewer so the UI will work.
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${GCR_ADMINS}" \
        --role roles/viewer

    # Grant admins access to do admin stuff.
    gsutil iam ch "group:${GCR_ADMINS}:objectAdmin" $(gcs_bucket_for ${project})
    gsutil iam ch "group:${GCR_ADMINS}:legacyBucketOwner" $(gcs_bucket_for ${project})
}

# Grant write privileges to a group
# $1: The GCP project
# $2: The googlegroups group
function empower_group() {
    if [ $# != 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group(proj_name, group_name) requires 2 arguments" > /dev/stderr
        return 1
    fi
    project="$1"
    group="$2"

    gsutil iam ch "group:${group}:objectAdmin" $(gcs_bucket_for ${project})
    gsutil iam ch "group:${group}:legacyBucketReader" $(gcs_bucket_for ${project})
}

# Grant full privileges to the GCR promoter bot
# $1: The GCP project
function empower_promoter() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "empower_promoter(proj_name) requires 1 argument" > /dev/stderr
        return 1
    fi
    project="$1"

    name="k8s-infra-gcr-promoter"
    acct=$(svc_acct_for "${project}" "${name}")

    if !  gcloud --project "${project}" iam service-accounts describe "${acct}" >/dev/null 2>&1; then
        gcloud --project "${project}" \
            iam service-accounts create \
            "${name}" \
            --display-name="k8s-infra container image promoter"
    fi

    # Grant admins access to do admin stuff.
    gsutil iam ch "serviceAccount:${acct}:objectAdmin" $(gcs_bucket_for ${project})
    gsutil iam ch "serviceAccount:${acct}:legacyBucketOwner" $(gcs_bucket_for ${project})
}

# Configure bucket lifecycle for a staging repo
# $1: The GCP project
function ensure_staging_lifecycle() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "ensure_staging_lifecycle(proj_name) requires 1 arguments" > /dev/stderr
        return 1
    fi
    project="$1"

    # Set lifecycle policies.
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
        ' | gsutil lifecycle set /dev/stdin $(gcs_bucket_for ${project})
}

# Configure bucket lifecycle for a prod repo
# $1: The GCP project
function ensure_prod_lifecycle() {
    if [ $# != 1 -o -z "$1" ]; then
        echo "ensure_prod_lifecycle(proj_name) requires 1 arguments" > /dev/stderr
        return 1
    fi
    project="$1"

    # Set lifecycle policies.
    gsutil retention set 5y $(gcs_bucket_for ${project})

    #TODO: maybe we want to lock this?
}
