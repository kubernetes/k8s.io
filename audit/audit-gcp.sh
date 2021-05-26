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

# TODO: Including this automatically calls verify_prereqs, which looks for yq,
#       which is not present in gcr.io/k8s-staging-releng/releng-ci:latest, the
#       image used to run this script at present. Update to use an image that
#       does have it installed, or at least pip3. In the meantime, copy-paste
#       the indent function.
# . "${REPO_ROOT}/infra/gcp/lib.sh"

# ensure_gnu_sed
# Determines which sed binary is gnu-sed on linux/darwin
#
# Sets:
#  SED: The name of the gnu-sed binary
#
function ensure_gnu_sed() {
    sed_help="$(LANG=C sed --help 2>&1 || true)"
    if echo "${sed_help}" | grep -q "GNU\|BusyBox"; then
        SED="sed"
    elif command -v gsed &>/dev/null; then
        SED="gsed"
    else
        >&2 echo "Failed to find GNU sed as sed or gsed. If you are on Mac: brew install gnu-sed"
        return 1
    fi
    export SED
}

# Indent each line of stdin.
# example: <command> 2>&1 | indent
function indent() {
    ${SED} -u 's/^/  /'
}

readonly AUDIT_DIR="${REPO_ROOT}/audit"
readonly KUBERNETES_IO_GCP_ORG="758905017065" # kubernetes.io

# TODO: this should delegate to verify_prereqs from infra/gcp/lib_util.sh once
#       we can guarantee this runs in an image with `yq` and/or pip3 installed
function ensure_dependencies() {
    # indent relies on sed -u which isn't available in macOS's sed
    if ! ensure_gnu_sed; then
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "jq not found. Please install: https://stedolan.github.io/jq/download/" >&2
        exit 1
    fi

    # the 'bq show' command is called as a hack to dodge the config prompts that bq presents
    # the first time it is run. A newline is passed to stdin to skip the prompt for default project
    # when the service account in use has access to multiple projects.
    if ! bq show <<< $'\n' >/dev/null; then
        # ignore errors from bq while doing this hack
        true
    fi

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
        gcloud iam roles describe "${role}" \
            --organization="${org_id}" \
            --format=json | format_gcloud_json \
            > "${org_dir}/roles/${role}.json"
    done
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

    echo "Exporting enabled services for project: ${project}"
    ensure_clean_dir "projects/${project}/services"
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
    local service_dir="projects/${project}/services/${service}"
    ensure_clean_dir "${service_dir}"

    case "${service}" in
        bigquery)
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
        compute)
            gcloud \
                compute project-info describe \
                --project="${project}" \
                --format=json | format_gcloud_json \
                | jq 'del(.quotas[].usage, .commonInstanceMetadata.fingerprint)' \
                > "${service_dir}/project-info.json"
            ;;
        container)
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
            ;;
        dns)
            gcloud \
                dns project-info describe "${project}" \
                --format=json | format_gcloud_json \
                > "${service_dir}/info.json"
            gcloud \
                dns managed-zones list \
                --project="${project}" \
                --format=json | format_gcloud_json \
                > "${service_dir}/zones.json"
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
            local buckets_dir="projects/${project}/buckets"
            ensure_clean_dir "${buckets_dir}"
            # save gsutil calls by listing all buckets at once, then splitting
            # into separate files with awk after the fact
            gsutil ls -L -b -p "${project}" \
                | awk "/^gs:/ { split(\$1,a,\"/\"); f=\"${buckets_dir}/\" a[3] \".txt\"} {print > f}"
            mapfile -t buckets < <(
                find "${buckets_dir}" -name '*.txt' -maxdepth 1 -exec basename {} .txt \;
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
                gsutil iam get "gs://${bucket}" \
                    | format_gcloud_json \
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
        storage-component)
            echo "skipping; same resources as storage-api"
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
            ;;
    esac
}

function audit_k8s_infra_gcp() {
    echo "Removing all existing GCP project audit files"
    remove_all_gcp_project_audit_files 2>&1 | indent

    echo "Exporting GCP organization: kubernetes.io"
    audit_gcp_organization "kubernetes.io" 2>&1 | indent

    # TODO: this will miss projects that are under folders
    echo "Exporting all GCP projects with parent id: ${KUBERNETES_IO_GCP_ORG}"
    audit_all_projects_with_parent_id "${KUBERNETES_IO_GCP_ORG}" 2>&1 | indent
}

function migrate_audit_format() {
    local migrated=false
    local projects=("$@")
    if [ $# -eq 0 ]; then
        mapfile -t projects < <(echo projects/* | xargs basename)
    fi

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
    ensure_dependencies
    migrate_audit_format "$@"

    if [ $# -gt 0 ]; then
        for project in "$@"; do
            echo "Exporting GCP project: ${project}"
            audit_gcp_project "${project}" 2>&1 | indent
        done
    else
        audit_k8s_infra_gcp
    fi
    echo "Done"
}

main "$@"
