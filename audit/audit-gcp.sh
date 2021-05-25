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

readonly CNCF_GCP_ORG=758905017065

function format_gcloud_json() {
    # recursively delete any fields named "etag"
    jq 'delpaths([path(..|.etag?|select(.))])'
}

function remove_all_gcp_project_audit_files() {
    echo "# Removing existing audit files"
    rm -rf projects
}

function audit_gcp_organization() {
    local organization="${1}"
    echo "# Auditing CGP Org: ${organization}"

    echo "## Removing existing audit files for organization: ${organization}"
    rm -rf org_kubernetes.io

    echo "## Exporting IAM roles for organization: ${organization}"
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

    echo "## Exporting IAM policy for org: ${organization}"
    rm -rf org_kubernetes.io/iam.json
    gcloud \
        organizations get-iam-policy "${organization}" \
        --format=json | format_gcloud_json \
        > "org_kubernetes.io/iam.json"

}

function audit_all_projects_with_parent_id() {
    local parent_id="${1}"
    echo "## Auditing all projects with parent id: ${parent_id}"
    echo "## Removing existing audit files"
    rm -rf projects
    gcloud \
        projects list \
        --filter="parent.id=${parent_id}" \
        --format="value(name, projectNumber)" \
    | sort \
    | while read -r PROJECT NUM; do
        audit_gcp_project "${PROJECT}" "${NUM}"
    done
}

function audit_gcp_project() {
    local PROJECT="${1}"
    local NUM="${2}"

    export CLOUDSDK_CORE_PROJECT="${PROJECT}"

    echo "### Auditing Project ${PROJECT}"

    echo "#### Removing existing audit files for project: ${PROJECT}"
    rm -rf "projects/${PROJECT}"

    mkdir -p "projects/${PROJECT}"

    echo "#### Exporting project description for project: ${PROJECT}"
    gcloud \
        projects describe "${PROJECT}" \
        --format=json | format_gcloud_json \
        > "projects/${PROJECT}/description.json"

    echo "#### Exporting IAM policy for project: ${PROJECT}"
    gcloud \
        projects get-iam-policy "${PROJECT}" \
        --format=json | format_gcloud_json \
        > "projects/${PROJECT}/iam.json"

    echo "#### Exporting IAM serviceaccounts for project: ${PROJECT}"
    gcloud \
        iam service-accounts list \
        --project="${PROJECT}" \
        --format="value(email)" \
    | while read -r SVCACCT; do
        mkdir -p "projects/${PROJECT}/service-accounts/${SVCACCT}"
        gcloud \
            iam service-accounts describe "${SVCACCT}" \
            --project="${PROJECT}" \
            --format=json | format_gcloud_json \
            > "projects/${PROJECT}/service-accounts/${SVCACCT}/description.json"
        gcloud \
            iam service-accounts get-iam-policy "${SVCACCT}" \
            --project="${PROJECT}" \
            --format=json | format_gcloud_json \
            > "projects/${PROJECT}/service-accounts/${SVCACCT}/iam.json"
    done

    echo "#### Exporting IAM roles for project: ${PROJECT}"
    gcloud \
        iam roles list \
        --project="${PROJECT}" \
        --format="value(name)" \
    | while read -r ROLE_PATH; do
        mkdir -p "projects/${PROJECT}/roles"
        ROLE=$(basename "${ROLE_PATH}")
        gcloud \
            iam roles describe "${ROLE}" \
            --project="${PROJECT}" \
            --format=json | format_gcloud_json \
            > "projects/${PROJECT}/roles/${ROLE}.json"
    done

    echo "#### Exporting enabled services for project: ${PROJECT}"
    mkdir -p "projects/${PROJECT}/services"
    gcloud \
        services list \
        --filter="state:ENABLED" \
        > "projects/${PROJECT}/services/enabled.txt"

    echo "#### Exporting resources for all enabled services for project: ${PROJECT}"
    gcloud \
        services list \
        --filter="state:ENABLED" \
        --format="value(config.name)" \
    | sed 's/.googleapis.com//' \
    | while read -r SVC; do
        echo "##### Exporting resources for service ${SVC} for project: ${PROJECT}"
        audit_gcp_project_service "${PROJECT}" "${SVC}"
    done
}

function audit_gcp_project_service() {
    local PROJECT="${1}"
    local SVC="${2}"
    case "${SVC}" in
        bigquery)
            mkdir -p "projects/${PROJECT}/services/${SVC}"
            bq \
                ls \
                --project_id="${PROJECT}" \
                --format=json | format_gcloud_json \
                > "projects/${PROJECT}/services/${SVC}/bigquery.datasets.json"
            # Only run if there are any datasets
            if [ -s "projects/${PROJECT}/services/${SVC}/bigquery.datasets.json" ]
            then
                bq \
                    ls \
                    --project_id="${PROJECT}" \
                    --format=json | format_gcloud_json \
                    | jq -r '.[] | .datasetReference["datasetId"]' \
                    | while read -r DATASET; do
                        bq \
                            show \
                            --project_id="${PROJECT}" \
                            --format=json \
                            "${PROJECT}:${DATASET}" \
                            | format_gcloud_json \
                            | jq .access \
                            > "projects/${PROJECT}/services/${SVC}/bigquery.datasets.${DATASET}.access.json"
                    done
            fi
            ;;
        compute)
            mkdir -p "projects/${PROJECT}/services/${SVC}"
            gcloud \
                compute project-info describe \
                --project="${PROJECT}" \
                --format=json | format_gcloud_json \
                | jq 'del(.quotas[].usage, .commonInstanceMetadata.fingerprint)' \
                > "projects/${PROJECT}/services/${SVC}/project-info.json"
            ;;
        container)
            mkdir -p "projects/${PROJECT}/services/${SVC}"
            # Don't do a JSON dump here - too much changes without human
            # action.
            gcloud \
                container clusters list \
                --format="value(name, location, locations, status)" \
                > "projects/${PROJECT}/services/${SVC}/clusters.txt"
            ;;
        dns)
            mkdir -p "projects/${PROJECT}/services/${SVC}"
            gcloud \
                dns project-info describe "${PROJECT}" \
                --format=json | format_gcloud_json \
                > "projects/${PROJECT}/services/${SVC}/info.json"
            gcloud \
                dns managed-zones list \
                --format=json | format_gcloud_json \
                > "projects/${PROJECT}/services/${SVC}/zones.json"
            ;;
        logging)
            echo "TODO: ${SVC} needs serviceusage.services.use"
            ##### gcloud logging logs list --format=json > "projects/${PROJECT}/services/logging.logs.json"
            ##### gcloud logging metrics list --format=json > "projects/${PROJECT}/services/logging.metrics.json"
            ##### gcloud logging sinks list --format=json > "projects/${PROJECT}/services/logging.sinks.json"
            ;;
        monitoring)
            echo "TODO: ${SVC} needs serviceusage.services.use"
            #### gcloud alpha monitoring policies list > "projects/${PROJECT}/services/monitoring.policies.json"
            #### gcloud alpha monitoring channels list > "projects/${PROJECT}/services/monitoring.channels.json"
            #### gcloud alpha monitoring channel-descriptors list > "projects/${PROJECT}/services/monitoring.channel-descriptors.json"
            ;;
        secretmanager)
            gcloud \
                secrets list \
                --project="${PROJECT}" \
                --format="value(name)" \
            | while read -r SECRET; do
                path="projects/${PROJECT}/secrets/${SECRET}"
                mkdir -p "${path}"
                gcloud \
                    secrets describe "${SECRET}" \
                    --project="${PROJECT}" \
                    --format=json | format_gcloud_json \
                    > "${path}/description.json"
                gcloud \
                    secrets versions list "${SECRET}" \
                    --project="${PROJECT}" \
                    --format=json \
                    > "${path}/versions.json"
                gcloud \
                    secrets get-iam-policy "${SECRET}" \
                    --project="${PROJECT}" \
                    --format=json | format_gcloud_json \
                    > "${path}/iam.json"
            done
            ;;
        storage-api)
            gsutil ls -p "${PROJECT}" \
            | awk -F/ '{print $3}' \
            | while read -r BUCKET; do
                mkdir -p "projects/${PROJECT}/buckets/${BUCKET}"
                gsutil bucketpolicyonly get "gs://${BUCKET}/" \
                    > "projects/${PROJECT}/buckets/${BUCKET}/bucketpolicyonly.txt"
                gsutil cors get "gs://${BUCKET}/" \
                    > "projects/${PROJECT}/buckets/${BUCKET}/cors.txt"
                gsutil logging get "gs://${BUCKET}/" \
                    > "projects/${PROJECT}/buckets/${BUCKET}/logging.txt"
                gsutil iam get "gs://${BUCKET}/" \
                    | format_gcloud_json \
                    > "projects/${PROJECT}/buckets/${BUCKET}/iam.json"
            done
            ;;
        *)
            echo "WARN: Unaudited service ${SVC} enabled in project: ${PROJECT}"
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

function main() {
    remove_all_gcp_project_audit_files
    audit_gcp_organization ${CNCF_GCP_ORG}
    audit_all_projects_with_parent_id ${CNCF_GCP_ORG}
}

main
