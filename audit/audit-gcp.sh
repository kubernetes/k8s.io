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

# Exports select GCP resources in the kubernetes.io organization managed
# by wg-k8s-infra, for purposes of auditing review.
#
# Must be run by an authenticated member of the GCP auditors group
# (k8s-infra-gcp-auditors@kubernetes.io) or as a service-account that has the
# custom organization IAM role "audit.viewer" assigned at the organization level
#
# Usage:
#
#   # remove/re-export all resources
#   audit-gcp.sh
#
#   # remove/re-export all resources in projects foo, bar
#   audit-gcp.sh foo bar
#
#   # remove/re-export (iam, gcs, monitoring) resources in project foo
#   K8S_INFRA_AUDIT_SERVICES="storage-api,monitoring" audit-gcp.sh foo

set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly REPO_ROOT
. "${REPO_ROOT}/infra/gcp/lib.sh"

#
# config
#

# where audit files will be exported
readonly AUDIT_DIR="${REPO_ROOT}/audit"

# hardcoded id for organization: kubernetes.io
readonly KUBERNETES_IO_GCP_ORG="758905017065"

# which services to try exporting; default empty, which means all
# e.g. K8S_INFRA_AUDIT_SERVICES="storage-api,monitoring" audit-gcp.sh k8s-infra-foo
AUDIT_SERVICES=()
IFS=', ' read -r -a AUDIT_SERVICES <<< "${K8S_INFRA_AUDIT_SERVICES:-""}"
readonly AUDIT_SERVICES

#
# utils
#

# TODO: this should delegate to verify_prereqs from infra/gcp/lib_util.sh once
#       we can guarantee this runs in an image with `yq` and/or pip3 installed
function ensure_audit_dependencies() {
    echo "bq"
    # the 'bq show' command is called as a hack to dodge the config prompts that bq presents
    # the first time it is run. A newline is passed to stdin to skip the prompt for default project
    # when the service account in use has access to multiple projects.
    if ! bq show <<< $'\n' >/dev/null; then
        # ignore errors from bq while doing this hack
        true
    fi

    echo "gcloud config"
    gcloud config list

    # right now most of this script assumes it's been run within the audit dir
    pushd "${AUDIT_DIR}" >/dev/null
}

function format_gcloud_json() {
    # recursively delete any fields named "etag"
    jq 'delpaths([path(..|.etag?|select(.))])'
}

function ensure_clean_dir() {
  rm -rf "${1}" && mkdir -p "${1}"
}

#
# main
#

function remove_all_gcp_project_audit_files() {
    rm -rf projects
}

function audit_gcp_organization() {
    local org_name="${1}"
    local org_id
    local org_dir="organizations/${org_name}"

    echo "Removing existing audit files for organization: ${org_name}"
    ensure_clean_dir "${org_dir}"

    echo "Exporting organization description for organization: ${org_name}"
    gcloud \
        organizations describe "${org_name}" \
        --format=json | format_gcloud_json \
    > "${org_dir}/description.json"

    # gcloud iam calls require the numeric organization id
    org_id=$(<"${org_dir}/description.json" jq -r .name | cut -d/ -f2)

    echo "Exporting IAM policy for organization: ${org_name}"
    gcloud \
        organizations get-iam-policy "${org_id}" \
        --format=json | format_gcloud_json \
    > "${org_dir}/iam.json"

    echo "Exporting IAM roles for organization: ${org_name}"
    ensure_clean_dir "${org_dir}/roles"
    mapfile -t roles < <(
        gcloud iam roles list --organization="${org_id}" --format="value(name)"
    )

    for role in "${roles[@]##*/}"; do
        echo "role: ${role}"
        gcloud \
            iam roles describe "${role}" \
            --organization="${org_id}" \
            --format=json | format_gcloud_json \
        > "${org_dir}/roles/${role}.json"
    done 2>&1 | indent
}

function audit_all_projects_with_parent_id() {
    local parent_id="${1}"
    echo "Removing existing audit files"
    ensure_clean_dir "projects/"
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
    local project_dir="projects/${project}"

    echo "Removing existing audit files for project: ${project}"
    ensure_clean_dir "${project_dir}"

    echo "Exporting project description for project: ${project}"
    gcloud \
        projects describe "${project}" \
        --format=json | format_gcloud_json \
    > "${project_dir}/description.json"

    echo "Exporting IAM policy for project: ${project}"
    gcloud \
        projects get-iam-policy "${project}" \
        --format=json | format_gcloud_json \
    > "${project_dir}/iam.json"

    echo "Exporting IAM serviceaccounts for project: ${project}"
    ensure_clean_dir "${project_dir}/service-accounts"
    gcloud \
        iam service-accounts list \
        --project="${project}" \
        --format="value(email)" \
    | while read -r SVCACCT; do
        echo "serviceaccount: ${SVCACCT}"
        mkdir -p "${project_dir}/service-accounts/${SVCACCT}"
        gcloud \
            iam service-accounts describe "${SVCACCT}" \
            --project="${project}" \
            --format=json | format_gcloud_json \
        > "${project_dir}/service-accounts/${SVCACCT}/description.json"
        gcloud \
            iam service-accounts get-iam-policy "${SVCACCT}" \
            --project="${project}" \
            --format=json | format_gcloud_json \
        > "${project_dir}/service-accounts/${SVCACCT}/iam.json"
    done

    echo "Exporting IAM roles for project: ${project}"
    ensure_clean_dir "projects/${project}/roles"
    gcloud \
        iam roles list \
        --project="${project}" \
        --format="value(name)" \
    | while read -r role_path; do
        role=$(basename "${role_path}")
        gcloud \
            iam roles describe "${role}" \
            --project="${project}" \
            --format=json | format_gcloud_json \
        > "${project_dir}/roles/${role}.json"
    done

    audit_gcp_project_services "${project}" "${AUDIT_SERVICES[@]}"
}

function audit_gcp_project_services() {
    local project="${1}"; shift
    local services=("$@")
    local which_services="manually specified"
    local services_dir="projects/${project}/services"

    echo "Exporting enabled services for project: ${project}"
    mkdir -p "${services_dir}"
    gcloud \
        services list \
        --project="${project}" \
        --filter="state:ENABLED" \
    > "${services_dir}/enabled.txt"

    if [ ${#services[@]} -eq 0 ]; then
        which_services="all enabled"
        mapfile -t services < <(<"${services_dir}/enabled.txt" tail +2 | cut -d' ' -f1)
        find "${services_dir}" -mindepth 1 -maxdepth 1 -type d | xargs --null rm -rf
    fi

    echo "Exporting resources for ${which_services} services for project: ${project}"
    for service in "${services[@]}"; do
        service="${service%.googleapis.com}"
        audit_gcp_project_service "${project}" "${service}"
    done 2>&1 | indent
}

function audit_gcp_project_service() {
    local project="${1}"
    local service="${2}"
    local service_dir="projects/${project}/services/${service}"
    local skip=true
    ensure_clean_dir "${service_dir}"

    case "${service}" in
        bigquerystorage)
            echo "Skipping service: ${service}, no resources to export"
            ;;
        cloudshell)
            echo "Skipping service: ${service}, no resources to export"
            ;;
        iam)
            # TODO: ideally we would export iam resources here instead of elsewhere
            echo "Skipping service: ${service}, handled outside of service export"
            # TODO: gcloud iam workload-identity-pools
            ;;
        iamcredentials)
            echo "Skipping service: ${service}, no resources to export"
            ;;
        oslogin)
            echo "Skipping service: ${service}, no resources to export"
            ;;
        serviceusage)
            echo "Skipping service: ${service}, no resources to export"
            ;;
        storage-component)
            echo "Skipping service: ${service}, same resources as handled service: storage-api"
            ;;
        *)
            echo "Exporting resources for service: ${service}, project: ${project}"
            skip=false
            ;;
    esac

    if "${skip}"; then
        return
    fi

    case "${service}" in
        bigquery)
            echo "datasets"
            bq \
                ls \
                --project_id="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/bigquery.datasets.json"
            # Only run if there are any datasets
            if [ -s "${service_dir}/bigquery.datasets.json" ]
            then
                bq \
                    ls \
                    --project_id="${project}" \
                    --format=json | format_gcloud_json \
                    | jq -r '.[] | .datasetReference["datasetId"]' \
                    | while read -r DATASET; do
                        echo "dataset access: ${DATASET}"
                        bq \
                            show \
                            --project_id="${project}" \
                            --format=json \
                            "${project}:${DATASET}" \
                            | format_gcloud_json \
                        | jq .access \
                        > "${service_dir}/bigquery.datasets.${DATASET}.access.json"
                    done
            fi
            ;;
        cloudasset)
            echo "feeds"
            gcloud \
                asset feeds list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/feeds.json"
            if [ "$(cat "${service_dir}/feeds.json")" == "{}" ]; then
                rm "${service_dir}/feeds.json"
            fi
            ;;
        cloudfunctions)
            echo "functions"
            gcloud \
                functions list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/functions.json"
            if [ "$(cat "${service_dir}/functions.json")" == "[]" ]; then
                rm "${service_dir}/functions.json"
            fi
            ;;
        cloudresourcemanager)
            # TODO: this service should maybe be ignored and done as a special-case at the org level
            echo "org-policies"
            gcloud \
                resource-manager org-policies list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/org-policies.json"
            if [ "$(cat "${service_dir}/org-policies.json")" == "[]" ]; then
                rm "${service_dir}/org-policies.json"
            fi
            # TODO: gcloud alpha resource-manager liens ?
            # TODO: gcloud alpha resource-manager tags ?
            ;;
        compute)
            echo "project-info"
            gcloud \
                compute project-info describe \
                --project="${project}" \
                --format=json | format_gcloud_json \
            | jq 'del(.quotas[].usage, .commonInstanceMetadata.fingerprint)' \
            > "${service_dir}/project-info.json"
            # TODO: gcloud compute * ?
            ;;
        container)
            echo "clusters"
            # TODO: this may get noisy since there are things that change
            # without human interaction; prune more fields as discovered
            local clusters_dir="${service_dir}/clusters"
            ensure_clean_dir "${clusters_dir}"
            gcloud \
                container clusters list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            | jq -r 'map("\(.name) \(.)")[]' \
            | while read -r name json; do \
                echo "cluster: ${name}"
                echo "${json}" \
                    | jq 'del(.masterAuth, .status, .nodePools[].status, .currentNodeCount)' \
                > "${clusters_dir}/${name}.json"
            done
            # TODO: gcloud container binauthz ?
            # TODO: gcloud container node-pools ?
            # TODO: gcloud container subnets ?
            ;;
        datastore)
            echo "TODO: insufficient permissions"
            # TODO: gcloud datatore indexes list # ERROR: (gcloud.datastore.indexes.list) caller does not have permission
            ;;
        dns)
            echo "project-info"
            gcloud \
                dns project-info describe "${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/info.json"
            echo "managed-zones"
            gcloud \
                dns managed-zones list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/zones.json"
            # TODO: gcloud dns dns-keys ?
            # TODO: gcloud dns polocies ?
            # TODO: gcloud dns record-sets ?
            ;;
        logging)
            # TODO: does this service actually need serviceusage.services.use?
            echo "logs"
            if [[ "${project}" =~ ^k8s-infra-e2e-.* ]]; then
                echo "skipping for ${project}; logs from e2e test pods are causing noisy churn"
            else
                gcloud \
                    logging logs list \
                    --project="${project}" \
                    --format=json | format_gcloud_json \
                > "${service_dir}/logs.json"
            fi
            echo "metrics"
            gcloud \
                logging metrics list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/metrics.json"
            if [ "$(cat "${service_dir}/metrics.json")" == "[]" ]; then
                rm "${service_dir}/metrics.json"
            fi
            echo "sinks"
            gcloud \
                logging sinks list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/sinks.json"
            # TODO: gcloud logging buckets ?
            # TODO: gcloud logging views ?
            ;;
        monitoring)
            # TODO: does this service actually need serviceusage.services.use?
            echo "dashboards"
            local dashboards_dir="${service_dir}/dashboards"
            ensure_clean_dir "${dashboards_dir}"
            gcloud \
                monitoring dashboards list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            | jq -r 'map("\(.displayName) \(.)")[]' \
            | while read -r name json; do \
                echo "dashboard: ${name}"
                echo "${json}" \
                > "${dashboards_dir}/${name}.json"
            done
            # TODO: gcloud beta monitoring channel-descriptors
            # TODO: gcloud beta monitoring channels list
            # TODO gcloud alpha monitoring policies list
            ;;
        pubsub)
            echo "snapshots"
            gcloud \
                pubsub snapshots list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/snapshots.json"
            if [ "$(cat "${service_dir}/snapshots.json")" == "[]" ]; then
                rm "${service_dir}/snapshots.json"
            fi
            echo "subscriptions"
            gcloud \
                pubsub subscriptions list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/subscriptions.json"
            if [ "$(cat "${service_dir}/subscriptions.json")" == "[]" ]; then
                rm "${service_dir}/subscriptions.json"
            fi
            echo "topics"
            gcloud \
                pubsub topics list \
                --project="${project}" \
                --format=json | format_gcloud_json \
            > "${service_dir}/topics.json"
            if [ "$(cat "${service_dir}/topics.json")" == "[]" ]; then
                rm "${service_dir}/topics.json"
            fi
            # TODO: gcloud pubsub lite-subscriptions ?
            # TODO: gcloud pubsub lite-topics ?
            ;;
        secretmanager)
            gcloud \
                secrets list \
                --project="${project}" \
                --format="value(name)" \
            | while read -r SECRET; do
                echo "secret: ${SECRET}"
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
            local buckets_dir="projects/${project}/buckets"
            ensure_clean_dir "${buckets_dir}"
            # save gsutil calls by listing all buckets at once, then splitting
            # into separate files with awk after the fact
            gsutil ls -L -b -p "${project}" \
                | awk "/^gs:/ { split(\$1,a,\"/\"); f=\"${buckets_dir}/\" a[3] \".txt\"} {print > f}"
            mapfile -t buckets < <(
                find "${buckets_dir}" -maxdepth 1 -name '*.txt' -exec basename {} .txt \;
            )
            for bucket in "${buckets[@]}"; do
                echo "bucket: ${bucket}"
                local bucket_dir="${buckets_dir}/${bucket}"
                ensure_clean_dir "${bucket_dir}"
                mv "${buckets_dir}/${bucket}"{,/metadata}.txt
            done
            # save gsutil calls for per-bucket configuration by only getting
            # configuration that is Present according to bucket metadata
            for bucket in "${buckets[@]}"; do
                local bucket_dir="${buckets_dir}/${bucket}"
                echo "bucket iam: ${bucket}"
                gsutil iam get "gs://${bucket}" | format_gcloud_json \
                > "${bucket_dir}/iam.json"
                if grep -q "Logging configuration:.*Present" "${bucket_dir}/metadata.txt"; then
                    echo "bucket logging: ${bucket}"
                    gsutil logging get "gs://${bucket}" \
                    > "${bucket_dir}/logging.json"
                fi
                if grep -q "Retention Policy:.*Present" "${bucket_dir}/metadata.txt"; then
                    echo "bucket retention: ${bucket}"
                    gsutil retention get "gs://${bucket}" \
                    > "${bucket_dir}/retention.txt"
                fi
                if grep -q "Lifecycle configuration:.*Present" "${bucket_dir}/metadata.txt"; then
                    echo "bucket lifecycle: ${bucket}"
                    gsutil lifecycle get "gs://${bucket}" \
                    > "${bucket_dir}/lifecycle.json"
                fi
            done
            ;;
        *)
            echo "WARN: Unaudited service ${service} enabled in project: ${project}"
            # TODO: handle or ignore: NAME
            # TODO: handle or ignore: admin
            # TODO: handle or ignore: bigqueryconnection
            # TODO: handle or ignore: bigquerydatatransfer
            # TODO: handle or ignore: bigqueryreservation
            # TODO: handle or ignore: cloudapis
            # TODO: handle or ignore: cloudbuild
            # TODO: handle or ignore: clouddebugger
            # TODO: handle or ignore: clouderrorreporting
            # TODO: handle or ignore: cloudkms
            # TODO: handle or ignore: cloudtrace
            # TODO: handle or ignore: containeranalysis
            # TODO: handle or ignore: containerregistry
            # TODO: handle or ignore: containerscanning
            # TODO: handle or ignore: deploymentmanager
            # TODO: handle or ignore: groupssettings
            # TODO: handle or ignore: run
            # TODO: handle or ignore: servicemanagement
            # TODO: handle or ignore: serviceusage
            # TODO: handle or ignore: source
            # TODO: handle or ignore: sql-component
            # TODO: handle or ignore: stackdriver
            ;;
    esac 2>&1 | indent
}

function audit_k8s_infra_gcp() {
    echo "Removing all existing GCP project audit files"
    remove_all_gcp_project_audit_files 2>&1 | indent

    echo "Exporting GCP organization: kubernetes.io"
    audit_gcp_organization "kubernetes.io" 2>&1 | indent

    # TODO: this will miss projects that are under folders
    echo "Exporting all GCP projects with parent id: ${KUBERNETES_IO_GCP_ORG}"
    audit_all_projects_with_parent_id "${KUBERNETES_IO_GCP_ORG}" 2>&1 | indent

    echo "Done"
}

function migrate_audit_format() {
    local migrated=false
    local projects=("$@")
    if [ $# -eq 0 ]; then
        mapfile -t projects < <(echo projects/* | xargs basename)
    fi

    echo "Migrating audit format for projects: ${projects[*]}"

    if [ -d org_kubernetes.io ]; then
        mkdir -p organizations/kubernetes.io
        git mv org_kubernetes.io/* organizations/kubernetes.io
        rm -rf org_kubernetes.io
        migrated=true
    fi

    for project in "${projects[@]}"; do
        local project_dir=projects/${project}

        # migrate container)
        local old_clusters="${project_dir}/services/container/clusters.txt"
        if [ -f "${old_clusters}" ]; then
            local clusters_dir="${project_dir}/services/container/clusters"
            mkdir -p "${clusters_dir}"
            while read -r name zone _; do
                local new_cluster="${clusters_dir}/$name.json"
                echo "{ \"name\": \"$name\", \"location\": \"$zone\" }" \
                    | jq > "${new_cluster}"
                git add "${new_cluster}"
            done <"${old_clusters}"
            git rm "${old_clusters}"
            migrated=true
        fi

        # migrate storage-api)
        local cors ubla logging
        for bucket in $(find "${project_dir}" -name 'bucketpolicyonly.txt' | cut -d/ -f4 | sort); do
            local bucket_dir=${project_dir}/buckets/${bucket}
            cors="None"
            if ! grep -q "has no CORS configuration" "${bucket_dir}/cors.txt"; then
                # not actually sure what it would be, none of our buckets have it
                cors="Present"
            else
                git rm "${bucket_dir}/cors.txt"
            fi
            logging="None"
            if ! grep -q "has no logging configuration" "${bucket_dir}/logging.txt"; then
                logging="Present"
                git mv "${bucket_dir}/logging.txt" "${bucket_dir}/logging.json"
            else
                git rm "${bucket_dir}/logging.txt"
            fi
            ubla="False"
            if grep -q "Enabled: True" "${bucket_dir}/bucketpolicyonly.txt"; then
                ubla="True"
            fi
            git rm "${bucket_dir}/bucketpolicyonly.txt"

            # there are very intentionally tab characters in this, since that's what gsutil outputs
            cat >"${bucket_dir}/metadata.txt" <<EOF
gs://${bucket}/ :
	Storage class:			STANDARD
	Location type:			multi-region
	Location constraint:		US
	Versioning enabled:		None
	Logging configuration:		${logging}
	Website configuration:		None
	CORS configuration: 		${cors}
	Lifecycle configuration:	None
	Requester Pays enabled:		None
	Labels:				None
	Default KMS key:		None
	Time created:			TBD
	Time updated:			TBD
	Metageneration:			8
	Bucket Policy Only enabled:	${ubla}
	ACL:				[]
	Default ACL:			[]
EOF
              git add "${bucket_dir}/metadata.txt"
              migrated=true
         done

    done

    if ${migrated}; then
        git commit -m "audit: migrate to new file layout"
    fi
}

function main() {
    local projects=("$@")
    echo "Ensuring dependencies"
    ensure_audit_dependencies

    migrate_audit_format "${projects[@]}"

    if [ "${#projects[@]}" -eq 0 ]; then
        audit_k8s_infra_gcp
    else
        for project in "$@"; do
            echo "Exporting GCP project: ${project} services: ${AUDIT_SERVICES[*]}"
            audit_gcp_project "${project}" 2>&1 | indent
        done
    fi

    echo "Done"
}

main "$@"
