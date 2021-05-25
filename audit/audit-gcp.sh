#!/usr/bin/env bash

# Copyright 2018 The Kubernetes Authors.
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

set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly REPO_ROOT
. "${REPO_ROOT}/infra/gcp/lib.sh"

readonly KUBERNETES_IO_GCP_ORG="${GCP_ORG}"
readonly AUDIT_DIR="${REPO_ROOT}/audit"

# TODO: this should maybe just be a call to verify_prereqs from lib_util.sh,
#       but that currently enforces presence of `yq` which I'm not sure is
#       present on the image used by the prowjob that runs this script
function ensure_dependencies() {
    if ! command -v jq &>/dev/null; then
      >&2 echo "jq not found. Please install: https://stedolan.github.io/jq/download/"
      exit 1
    fi

    # the 'bq show' command is called as a hack to dodge the config prompts that bq presents
    # the first time it is run. A newline is passed to stdin to skip the prompt for default project
    # when the service account in use has access to multiple projects.
    bq show <<< $'\n' >/dev/null

    # right now most of this script assumes it's been run within the audit dir
    pushd "${AUDIT_DIR}" >/dev/null
}

function format_gcloud_json() {
    # recursively delete any fields named "etag"
    jq 'delpaths([path(..|.etag?|select(.))])'
}

function remove_all_gcp_project_audit_files() {
    rm -rf projects
}

function audit_gcp_organization() {
    local organization="${1}"

    echo "Removing existing audit files for organization: ${organization}"
    rm -rf org_kubernetes.io

    echo "Exporting IAM roles for organization: ${organization}"
    rm -rf org_kubernetes.io/roles
    mkdir -p org_kubernetes.io/roles
    gcloud \
        iam roles list \
        --organization="${organization}" \
        --format="value(name)" \
    | while read -r ROLE_PATH; do
        ROLE=$(basename "${ROLE_PATH}")
        gcloud iam roles describe "${ROLE}" \
            --organization="${organization}" \
            --format=json | format_gcloud_json \
            > "org_kubernetes.io/roles/${ROLE}.json"
    done

    echo "Exporting IAM policy for organization: ${organization}"
    rm -rf org_kubernetes.io/iam.json
    gcloud \
        organizations get-iam-policy "${organization}" \
        --format=json | format_gcloud_json \
        > "org_kubernetes.io/iam.json"

}

function audit_all_projects_with_parent_id() {
    local parent_id="${1}"
    echo "Removing existing audit files"
    rm -rf projects
    gcloud \
        projects list \
        --filter="parent.id=${parent_id}" \
        --format="value(name)" \
    | sort \
    | while read -r project; do
        echo "Exporting GCP project: ${project}"
        audit_gcp_project "${project}" 2>&1 | indent
    done
}

function audit_gcp_project() {
    local project="${1}"

    echo "Removing existing audit files for project: ${project}"
    rm -rf "projects/${project}"

    mkdir -p "projects/${project}"

    echo "Exporting project description for project: ${project}"
    gcloud \
        projects describe "${project}" \
        --format=json | format_gcloud_json \
        > "projects/${project}/description.json"

    echo "Exporting IAM policy for project: ${project}"
    gcloud \
        projects get-iam-policy "${project}" \
        --format=json | format_gcloud_json \
        > "projects/${project}/iam.json"

    echo "Exporting IAM serviceaccounts for project: ${project}"
    gcloud \
        iam service-accounts list \
        --project="${project}" \
        --format="value(email)" \
    | while read -r SVCACCT; do
        mkdir -p "projects/${project}/service-accounts/${SVCACCT}"
        gcloud \
            iam service-accounts describe "${SVCACCT}" \
            --project="${project}" \
            --format=json | format_gcloud_json \
            > "projects/${project}/service-accounts/${SVCACCT}/description.json"
        gcloud \
            iam service-accounts get-iam-policy "${SVCACCT}" \
            --project="${project}" \
            --format=json | format_gcloud_json \
            > "projects/${project}/service-accounts/${SVCACCT}/iam.json"
    done

    echo "Exporting IAM roles for project: ${project}"
    gcloud \
        iam roles list \
        --project="${project}" \
        --format="value(name)" \
    | while read -r ROLE_PATH; do
        mkdir -p "projects/${project}/roles"
        ROLE=$(basename "${ROLE_PATH}")
        gcloud \
            iam roles describe "${ROLE}" \
            --project="${project}" \
            --format=json | format_gcloud_json \
            > "projects/${project}/roles/${ROLE}.json"
    done

    echo "Exporting enabled services for project: ${project}"
    mkdir -p "projects/${project}/services"
    gcloud \
        services list \
        --project="${project}" \
        --filter="state:ENABLED" \
        > "projects/${project}/services/enabled.txt"

    echo "Exporting resources for all enabled services for project: ${project}"
    gcloud \
        services list \
        --project="${project}" \
        --filter="state:ENABLED" \
        --format="value(config.name)" \
    | sed 's/.googleapis.com//' \
    | while read -r service; do
        echo "Exporting resources for service: ${service}, project: ${project}"
        audit_gcp_project_service "${project}" "${service}" 2>&1 | indent
    done 2>&1 | indent
}

function audit_gcp_project_service() {
    local project="${1}"
    local service="${2}"

    case "${service}" in
        bigquery)
            mkdir -p "projects/${project}/services/${service}"
            bq \
                ls \
                --project_id="${project}" \
                --format=json | format_gcloud_json \
                > "projects/${project}/services/${service}/bigquery.datasets.json"
            # Only run if there are any datasets
            if [ -s "projects/${project}/services/${service}/bigquery.datasets.json" ]
            then
                bq \
                    ls \
                    --project_id="${project}" \
                    --format=json | format_gcloud_json \
                    | jq -r '.[] | .datasetReference["datasetId"]' \
                    | while read -r DATASET; do
                        bq \
                            show \
                            --project_id="${project}" \
                            --format=json \
                            "${project}:${DATASET}" \
                            | format_gcloud_json \
                            | jq .access \
                            > "projects/${project}/services/${service}/bigquery.datasets.${DATASET}.access.json"
                    done
            fi
            ;;
        compute)
            mkdir -p "projects/${project}/services/${service}"
            gcloud \
                compute project-info describe \
                --project="${project}" \
                --format=json | format_gcloud_json \
                | jq 'del(.quotas[].usage, .commonInstanceMetadata.fingerprint)' \
                > "projects/${project}/services/${service}/project-info.json"
            ;;
        container)
            mkdir -p "projects/${project}/services/${service}"
            # Don't do a JSON dump here - too much changes without human
            # action.
            gcloud \
                container clusters list \
                --project="${project}" \
                --format="value(name, location, locations, status)" \
                > "projects/${project}/services/${service}/clusters.txt"
            ;;
        dns)
            mkdir -p "projects/${project}/services/${service}"
            gcloud \
                dns project-info describe "${project}" \
                --format=json | format_gcloud_json \
                > "projects/${project}/services/${service}/info.json"
            gcloud \
                dns managed-zones list \
                --project="${project}" \
                --format=json | format_gcloud_json \
                > "projects/${project}/services/${service}/zones.json"
            ;;
        logging)
            echo "TODO: ${service} needs serviceusage.services.use"
            ##### gcloud logging logs list --format=json > "projects/${project}/services/logging.logs.json"
            ##### gcloud logging metrics list --format=json > "projects/${project}/services/logging.metrics.json"
            ##### gcloud logging sinks list --format=json > "projects/${project}/services/logging.sinks.json"
            ;;
        monitoring)
            echo "TODO: ${service} needs serviceusage.services.use"
            #### gcloud alpha monitoring policies list > "projects/${project}/services/monitoring.policies.json"
            #### gcloud alpha monitoring channels list > "projects/${project}/services/monitoring.channels.json"
            #### gcloud alpha monitoring channel-descriptors list > "projects/${project}/services/monitoring.channel-descriptors.json"
            ;;
        secretmanager)
            gcloud \
                secrets list \
                --project="${project}" \
                --format="value(name)" \
            | while read -r SECRET; do
                path="projects/${project}/secrets/${SECRET}"
                mkdir -p "${path}"
                gcloud \
                    secrets describe "${SECRET}" \
                    --project="${project}" \
                    --format=json | format_gcloud_json \
                    > "${path}/description.json"
                gcloud \
                    secrets versions list "${SECRET}" \
                    --project="${project}" \
                    --format=json \
                    > "${path}/versions.json"
                gcloud \
                    secrets get-iam-policy "${SECRET}" \
                    --project="${project}" \
                    --format=json | format_gcloud_json \
                    > "${path}/iam.json"
            done
            ;;
        storage-api)
            gsutil ls -p "${project}" \
            | awk -F/ '{print $3}' \
            | while read -r BUCKET; do
                mkdir -p "projects/${project}/buckets/${BUCKET}"
                gsutil bucketpolicyonly get "gs://${BUCKET}/" \
                    > "projects/${project}/buckets/${BUCKET}/bucketpolicyonly.txt"
                gsutil cors get "gs://${BUCKET}/" \
                    > "projects/${project}/buckets/${BUCKET}/cors.txt"
                gsutil logging get "gs://${BUCKET}/" \
                    > "projects/${project}/buckets/${BUCKET}/logging.txt"
                gsutil iam get "gs://${BUCKET}/" \
                    | format_gcloud_json \
                    > "projects/${project}/buckets/${BUCKET}/iam.json"
            done
            ;;
        *)
            echo "WARN: Unaudited service ${service} enabled in project: ${project}"
            # (these were all enabled for kubernetes-public)
            # TODO: handle (or ignore) bigquerystorage
            # TODO: handle (or ignore) clouderrorreporting
            # TODO: handle (or ignore) cloudfunctions
            # TODO: handle (or ignore) cloudresourcemanager
            # TODO: handle (or ignore) cloudshell
            # TODO: handle (or ignore) containerregistry
            # TODO: handle (or ignore) iam
            # TODO: handle (or ignore) iamcredentials
            # TODO: handle (or ignore) oslogin
            # TODO: handle (or ignore) pubsub
            # TODO: handle (or ignore) serviceusage
            # TODO: handle (or ignore) source
            # TODO: handle (or ignore) stackdriver
            # TODO: handle (or ignore) storage-component
            ;;
    esac
}

function audit_k8s_infra_gcp() {
    echo "Removing all existing GCP project audit files"
    remove_all_gcp_project_audit_files 2>&1 | indent

    echo "Exporting GCP organization: ${organization}"
    audit_gcp_organization "${KUBERNETES_IO_GCP_ORG}" 2>&1 | indent

    # TODO: this will miss projects that are under folders
    echo "Exporting all GCP projects with parent id: ${KUBERNETES_IO_GCP_ORG}"
    audit_all_projects_with_parent_id "${KUBERNETES_IO_GCP_ORG}" 2>&1 | indent
}

function main() {
    ensure_dependencies
    if [ $# -gt 0 ]; then
        for project in "$@"; do
            echo "Exporting GCP project: ${project}"
            audit_gcp_project "${project}" 2>&1 | indent
        done
    else
        audit_k8s_infra_gcp
    fi
}

main "$@"
