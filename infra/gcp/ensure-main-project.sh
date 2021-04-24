#!/usr/bin/env bash

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

# This script creates & configures the "main" GCP project for Kubernetes.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0" > /dev/stderr
    echo > /dev/stderr
}

if [ $# != 0 ]; then
    usage
    exit 1
fi

# The GCP project name.
readonly PROJECT="kubernetes-public"

# The BigQuery dataset for billing data.
readonly BQ_BILLING_DATASET="kubernetes_public_billing"

# The BigQuery admins group.
readonly BQ_ADMINS_GROUP="k8s-infra-bigquery-admins@kubernetes.io"

# The cluster admins group.
readonly CLUSTER_ADMINS_GROUP="k8s-infra-cluster-admins@kubernetes.io"

# The accounting group.
readonly ACCOUNTING_GROUP="k8s-infra-gcp-accounting@kubernetes.io"

# The GCS bucket which hold terraform state for clusters
readonly LEGACY_CLUSTER_TERRAFORM_BUCKET="k8s-infra-clusters-terraform"

# The GKE security groups group
readonly CLUSTER_USERS_GROUP="gke-security-groups@kubernetes.io"

# The DNS admins group.
readonly DNS_GROUP="k8s-infra-dns-admins@kubernetes.io"

# GCS buckets to hold terraform state
#
# - since we are using uniform bucket level access (ubla), each bucket should
#   represent a logical group of access, with org admins given storage.admin
#   for break-glass purposes
# - the legacy bucket (k8s-infra-clusters-terraform) assumed the same set of
#   users should have access to all gke clusters (~all terraform-based infra)
# - new bucket schema is "k8s-infra-tf-{folder}[-{suffix}]" where:
#   - folder: intended GCP folder for GCP projects managed by this terraform,
#             access level is ~owners of folder
#   - suffix: some subset of resources contained somewhere underneath folder,
#             access level is ~editors of those resources
# - entry syntax is "bucket_name:owners_group" (: is invalid bucket name char)
readonly TERRAFORM_STATE_BUCKET_ENTRIES=(
    "${LEGACY_CLUSTER_TERRAFORM_BUCKET}:${CLUSTER_ADMINS_GROUP}"
    k8s-infra-tf-aws:k8s-infra-aws-admins@kubernetes.io
    k8s-infra-tf-prow-clusters:k8s-infra-prow-oncall@kubernetes.io
    k8s-infra-tf-public-clusters:"${CLUSTER_ADMINS_GROUP}"
    k8s-infra-tf-sandbox-ii:k8s-infra-ii-coop@kubernetes.io
)

# The services we explicitly want enabled for the main project
#
# NOTE: Expected services include dependencies of these services, which may be
#       more than direct dependencies. Do we care to statically encode the
#       graph here? ensure_only_services dynamically computes the set of
#       expected services
readonly MAIN_PROJECT_SERVICES=(
    # billing data gets exported to bigquery
    bigquery.googleapis.com
    # GKE clusters are hosted in this project
    container.googleapis.com
    # DNS zones are managed in this project
    dns.googleapis.com
    # We look at logs in this project (e.g. from GKE)
    logging.googleapis.com
    # We look at monitoring dashboards in this project
    monitoring.googleapis.com
    # Secrets are hosted in this project
    secretmanager.googleapis.com
    # GCS buckets are hosted in this project
    storage-component.googleapis.com
)

# Create a GCP service account intended for use by GKE cluster workloads
# $1: The GCP project hosting the service account (e.g. k8s-infra-foo)
# $2: The name of the GCP service account (e.g. k8s-infra-doer)
# $3: The IAM role the service account will have on the project (e.g. roles/foo.bar)
# $4: The GCP project hosting GKE cluster(s) that will use this service account (e.g. k8s-infra-foo-clusters)
# $5: The K8s namespace hosting the service account that will use this GCP SA (e.g. my-app-ns)
#
# e.g. the above allows pods running as my-app-ns/k8s-infra-doer in clusters in
#      k8s-infra-foo-clusters to act as k8s-infra-doer@k8s-infra-foo.iam.gserviceaccount.com,
#      using the permissions granted by roles/foo.bar on k8s-infra-foo
function ensure_workload_identity_serviceaccount() {
    if [ $# -lt 5 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
        echo "${FUNCNAME[0]}(project, name, role, cluster_project, cluster_namespace) requires 5 arguments" >&2
        return 1
    fi
    local serviceaccount_project="${1}"
    local serviceaccount_name="${2}"
    local serviceaccount_email
    serviceaccount_email="$(svc_acct_email "${serviceaccount_project}" "${serviceaccount_name}")"
    local serviceaccount_description="${serviceaccount_name}"
    local serviceaccount_role="${3}"
    local cluster_project="${4}"
    local cluster_namespace="${5}"

    color 6 "Ensuring serviceaccount ${serviceaccount_email} exists"
    ensure_service_account "${serviceaccount_project}" "${serviceaccount_name}" "${serviceaccount_description}"

    color 6 "Empowering ${serviceaccount_email} with role ${serviceaccount_role} in project ${serviceaccount_project}"
    ensure_project_role_binding \
        "${serviceaccount_project}" \
        "serviceAccount:${serviceaccount_email}" \
        "${serviceaccount_role}"

    local clusters="clusters in project ${cluster_project}"
    local k8s_sa="KSA ${cluster_namespace}/${serviceaccount_name}"
    local gcp_sa="GCP SA ${serviceaccount_email}"

    color 6 "Empowering ${clusters} to run workloads as ${k8s_sa} to act as ${gcp_sa}"
    empower_gke_for_serviceaccount "${cluster_project}" "${cluster_namespace}" "${serviceaccount_email}"
}

#
# main functions
#

function ensure_terraform_state_buckets() {
    if [ $# -ne 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(gcp_project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"

    for entry in "${TERRAFORM_STATE_BUCKET_ENTRIES[@]}"; do
        bucket="gs://$(echo "${entry}" | cut -d: -f1)"
        owners="$(echo "${entry}" | cut -d: -f2-)"
        color 6 "Ensuring '${bucket}' exists as private with owners '${owners}'"; (
            ensure_private_gcs_bucket "${project}" "${bucket}"
            empower_group_to_admin_gcs_bucket "${owners}" "${bucket}"
            ensure_gcs_role_binding "${bucket}" "group:k8s-infra-gcp-org-admins@kubernetes.io" "admin"
        ) 2>&1 | indent
    done
}

function empower_cluster_admins_and_users() {
    if [ $# -ne 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(gcp_project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"

    color 6 "Empowering cluster admins"
    # TODO(spiffxp): make this a custom role
    cluster_admin_roles=(
        roles/compute.viewer
        roles/container.admin
        roles/compute.loadBalancerAdmin
        "$(custom_org_role_name iam.serviceAccountLister)"
    )
    for role in "${cluster_admin_roles[@]}"; do
        ensure_project_role_binding "${project}" "group:${CLUSTER_ADMINS_GROUP}" "${role}"
    done
    # TODO(spiffxp): remove when these bindings have been removed
    removed_cluster_admin_roles=(
        "$(custom_project_role_name "${project}" ServiceAccountLister)"
    )
    for role in "${removed_cluster_admin_roles[@]}"; do
        ensure_removed_project_role_binding "${project}" "group:${CLUSTER_ADMINS_GROUP}" "${role}"
    done
    # TODO(spiffxp): ensure this is removed when the binding(s) using it have been removed
    ensure_removed_custom_project_iam_role "${project}" "ServiceAccountLister"

    color 6 "Empowering cluster users"
    ensure_project_role_binding \
        "${project}" \
        "group:${CLUSTER_USERS_GROUP}" \
        "roles/container.clusterViewer"
}


function ensure_dns() {
    if [ $# -ne 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(gcp_project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"

    local domains=(
        k8s.io
        kubernetes.io
        x-k8s.io
        k8s-e2e.com
    )

    color 6 "Empowering ${DNS_GROUP}"
    ensure_project_role_binding \
        "${project}" \
        "group:${DNS_GROUP}" \
        "roles/dns.admin"

    # Bootstrap DNS zones
    for domain in "${domains[@]}"; do
        # canary domain for each domain, e.g. k8s.io and canary.k8s.io
        for prefix in "" "canary."; do
            zone="${prefix}${domain}"
            name="${zone//./-}"
            color 6 "Ensuring DNS zone ${zone}"
            ensure_dns_zone "${project}" "${name}" "${zone}" 2>&1 | indent
        done
    done
}

function ensure_billing_bigquery() {
    if [ $# -ne 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(gcp_project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"

    color 6 "Empowering BigQuery admins"
    ensure_project_role_binding \
        "${project}" \
        "group:${BQ_ADMINS_GROUP}" \
        "roles/bigquery.admin"

    color 6 "Empowering GCP accounting"
    ensure_project_role_binding \
        "${project}" \
        "group:${ACCOUNTING_GROUP}" \
        "roles/bigquery.jobUser"

    color 6 "Creating the BigQuery dataset for billing data"
    if ! bq --project_id "${project}" ls "${BQ_BILLING_DATASET}" >/dev/null 2>&1; then
        bq --project_id "${project}" mk "${BQ_BILLING_DATASET}"
    fi

    color 6 "Setting BigQuery permissions"
    # Merge existing permissions with the ones we need to exist.  We merge
    # permissions because:
    #   * The full list is large and has stuff that is inherited listed in it
    #   * All of our other IAM binding logic calls are additive
    local before="${TMPDIR}/k8s-infra-bq-access.before.json"
    local ensure="${TMPDIR}/k8s-infra-bq-access.ensure.json"
    local final="${TMPDIR}/k8s-infra-bq-access.final.json"

    bq show --format=prettyjson "${project}":"${BQ_BILLING_DATASET}"  > "${before}"

    cat > "${ensure}" <<EOF
    {
      "access": [
        {
          "groupByEmail": "${ACCOUNTING_GROUP}",
          "role": "READER"
        },
        {
          "groupByEmail": "${ACCOUNTING_GROUP}",
          "role": "roles/bigquery.metadataViewer"
        },
        {
          "groupByEmail": "${ACCOUNTING_GROUP}",
          "role": "roles/bigquery.user"
        }
      ]
    }
EOF

    jq -s '.[0].access + .[1].access | { access: . }' "${before}" "${ensure}" > "${final}"

    bq update --source "${final}" "${project}":"${BQ_BILLING_DATASET}"

    color 4 "To enable billing export, a human must log in to the cloud"
    color 4 -n "console.  Go to "
    color 6 -n "Billing"
    color 4 -n "; "
    color 6 -n "Billing export"
    color 4 " and export to BigQuery"
    color 4 -n "in project "
    color 6 -n "${project}"
    color 4 -n " dataset "
    color 6 -n "${BQ_BILLING_DATASET}"
    color 4 " ."
    echo
    color 4 "Press enter to acknowledge"
    read -rs
}

function ensure_main_project() {
    if [ $# -ne 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(gcp_project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"

    color 6 "Ensuring project exists: ${project}"
    ensure_project "${project}" 2>&1 | indent

    color 6 "Ensuring main project services enabled for: ${project}"
    # TODO: there are many services that appear to have been enabled piecemeal
    #       and it's not yet clear which ones we actually rely upon, so this is
    #       not being run with K8S_INFRA_ENSURE_ONLY_SERVICES_WILL_FORCE_DISABLE
    ensure_only_services "${project}" "${MAIN_PROJECT_SERVICES[@]}" 2>&1 | indent

    color 6 "Ensuring terraform state buckets exist with correct permissions in: ${project}"
    ensure_terraform_state_buckets "${project}" 2>&1 | indent

    color 6 "Empowering cluster users and admins for clusters in: ${project}"
    empower_cluster_admins_and_users "${project}" 2>&1 | indent

    color 6 "Ensuring specific workload identity serviceaccounts exist in: ${project}"; (
        local svcacct_args cluster_args

        color 6 "Ensuring GCP Auditor serviceaccount"
        # roles/viewer on kubernetes-public is a bootstrap; the true purpose
        # is custom role audit.viewer on the kubernetes.io org, but that is
        # handled by ensure-organization.sh
        svcacct_args=("${project}" "k8s-infra-gcp-auditor" "roles/viewer")
        cluster_args=("k8s-infra-prow-build-trusted" "test-pods")
        ensure_workload_identity_serviceaccount "${svcacct_args[@]}" "${cluster_args[@]}" 2>&1 | indent

        # TODO(spiffxp): remove once this binding has been deleted
        local gcp_auditor_email
        gcp_auditor_email=$(svc_acct_email "${project}" "k8s-infra-gcp-auditor")
        color 6 "Ensuring removed workload identity on kubernetes-public/test-pods for ${gcp_auditor_email}"
        unempower_gke_for_serviceaccount \
            "kubernetes-public" \
            "test-pods" \
            "${gcp_auditor_email}" 2>&1 | indent

        color 6 "Ensuring DNS Updater serviceaccount"
        svcacct_args=("${project}" "k8s-infra-dns-updater" "roles/dns.admin")
        cluster_args=("k8s-infra-prow-build-trusted" "test-pods")
        ensure_workload_identity_serviceaccount "${svcacct_args[@]}" "${cluster_args[@]}" 2>&1 | indent

        color 6 "Ensuring Monitoring Viewer serviceaccount"
        svcacct_args=("${project}" "k8s-infra-monitoring-viewer" "roles/monitoring.viewer")
        cluster_args=("${project}" "monitoring")
        ensure_workload_identity_serviceaccount "${svcacct_args[@]}" "${cluster_args[@]}" 2>&1 | indent

        color 6 "Ensuring Kubernetes External Secrets serviceaccount"
        svcacct_args=("${project}" "kubernetes-external-secrets" "roles/secretmanager.secretAccessor")
        cluster_args=("${project}" "kubernetes-external-secrets")
        ensure_workload_identity_serviceaccount "${svcacct_args[@]}" "${cluster_args[@]}" 2>&1 | indent
    ) 2>&1 | indent

    color 6 "Ensuring DNS is configured in: ${project}"
    ensure_dns "${project}" 2>&1 | indent

    color 6 "Ensuring biquery configured for billing and access by appropriate groups in: ${project}"
    ensure_billing_bigquery "${project}" 2>&1 | indent

    color 6 "Done"
}

ensure_main_project "${PROJECT}"
