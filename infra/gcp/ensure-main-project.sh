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
PROJECT=$(k8s_infra_project "public" "kubernetes-public")
readonly PROJECT

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
    k8s-infra-tf-public-pii:"${CLUSTER_ADMINS_GROUP}"
    k8s-infra-tf-sandbox-ii:k8s-infra-ii-coop@kubernetes.io
)

# The services we explicitly want enabled for the main project
#
# NOTE: Expected services include dependencies of these services, which may be
#       more than direct dependencies. Do we care to statically encode the
#       graph here? ensure_only_services dynamically computes the set of
#       expected services
readonly MAIN_PROJECT_SERVICES=(
    # We export billing data to bigquery
    bigquery.googleapis.com
    # We use cloud asset inventory from this project to audit all projects
    cloudasset.googleapis.com
    # We require use of cloud shell to access clusters in this project
    cloudshell.googleapis.com
    # We host GKE clusters in this project
    container.googleapis.com
    # We manage kubernetes DNS zones in this project
    dns.googleapis.com
    # We look at logs in this project (e.g. from GKE)
    logging.googleapis.com
    # We look at monitoring dashboards in this project
    monitoring.googleapis.com
    # We host secrets in this project for use by prow and other apps
    secretmanager.googleapis.com
    # We host public-facing and private GCS buckets in this project
    storage-api.googleapis.com
    # TODO: do we really need the legacy XML API enabled for them though?
    storage-component.googleapis.com

    ## Dependencies
    # container.googleapis.com depends on compute
    compute.googleapis.com
    # container.googleapis.com depends on containerregistry
    containerregistry.googleapis.com
    # container.googleapis.com depends on iam
    iam.googleapis.com
    # container.googleapis.com, iam.googleapis.com depend on iamcredentials
    iamcredentials.googleapis.com
    # compute.googleapis.com, container.googleapis.com depend on oslogin
    oslogin.googleapis.com
    # container.googleapis.com, containerregistry.googleapis.com depend on pubsub
    pubsub.googleapis.com

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
            # ensure owners have storage.buckets.list permission for their bucket
            # TODO(spiffxp): figure out a way to do this per-bucket
            ensure_project_role_binding "${project}" "group:${owners}" "roles/viewer"
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

    # TODO(spiffxp): consider replacing this with a service account per namespace
    local prow_deployer_acct prow_deployer_role
    prow_deployer_acct="prow-deployer@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"
    # TODO(spiffxp): use container.deployer once we figure out why it isn't getting RBAC privileges
    old_prow_deployer_role=$(custom_org_role_name "container.deployer")
    prow_deployer_role=$(custom_org_role_name "container.deployer")
    color 6 "Empowering ${prow_deployer_acct} to deploy to clusters in project: ${project}"
    ensure_removed_project_role_binding "${project}" "serviceAccount:${prow_deployer_acct}" "${old_prow_deployer_role}"
    ensure_project_role_binding "${project}" "serviceAccount:${prow_deployer_acct}" "${prow_deployer_role}"

    color 6 "Empowering cluster users"
    cluster_user_roles=(
        roles/container.clusterViewer
        roles/logging.privateLogViewer
        roles/monitoring.viewer
    )
    for role in "${cluster_user_roles[@]}"; do
        ensure_project_role_binding "${project}" "group:${CLUSTER_USERS_GROUP}" "${role}"
    done
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

# Eventually we would like to use kubernetes-external-secrets to manage
# all secrets in aaa; not sure how far we are on that. So for now, at least
# ensure that the existing kubernetes-public secrets created for humans
# to manually sync into the aaa cluster are managed by this script.
function ensure_aaa_external_secrets() {
    if [ $# -ne 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"
    local secret_specs=()

    # another sign that we should move to using YAML as source of intent;
    # bash and indirect array access don't play nice, so we get this...

    # prow as in the k8s-infra-prow instance being stood up on aaa, not the
    # build clusters managed via infra/gcp/terraform/k8s-infra-prow-build*
    local prow_secrets=(
        k8s-infra-build-clusters-kubeconfig
        k8s-infra-ci-robot-github-account-password
        k8s-infra-ci-robot-github-token
        k8s-infra-prow-cookie
        k8s-infra-prow-github-oauth-config
        k8s-infra-prow-hmac-token
    )
    local slack_infra_secrets=(
        recaptcha
        slack-event-log-config
        slack-moderator-config
        slack-moderator-words-config
        slack-welcomer-config
        slackin-token
    )
    local triageparty_release_secrets=(
        triage-party-github-token
    )
    mapfile -t secret_specs < <(
        printf "%s/prow/sig-testing\n" "${prow_secrets[@]}"
        printf "%s/slack-infra/sig-contributor-experience\n" "${slack_infra_secrets[@]}"
        printf "%s/triageparty-release/sig-release\n" "${triageparty_release_secrets[@]}"
    )

    for spec in "${secret_specs[@]}"; do
        local secret app k8s_group
        secret="$(echo "${spec}" | cut -d/ -f1)"
        app="$(echo "${spec}" | cut -d/ -f2)"
        k8s_group="$(echo "${spec}" | cut -d/ -f3)"

        local admins="k8s-infra-rbac-${app}@kubernetes.io"
        local labels=("app=${app}" "group=${k8s_group}")

        color 6 "Ensuring '${app}' secret '${secret}' exists in '${project}' and is owned by '${admins}'"
        ensure_secret_with_admins "${project}" "${secret}" "${admins}"
        ensure_secret_labels "${project}" "${secret}" "${labels[@]}"
    done
}

# Special-case IAM bindings that are necessary for k8s-infra prow or
# its build clusters to operate on resources within the given project
function ensure_prow_special_cases {
    if [ $# -ne 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"

    local principal secret

    color 6 "Special case: ensuring k8s-infra-ci-robot-github-token accessible by k8s-infra-prow-build-trusted"
    principal="serviceAccount:$(svc_acct_email "k8s-infra-prow-build-trusted" "kubernetes-external-secrets")"
    secret=$(secret_full_name "${project}" "k8s-infra-ci-robot-github-token")
    ensure_secret_role_binding "${secret}" "${principal}" "roles/secretmanager.secretAccessor" 2>&1 | indent

    color 6 "Special case: ensuring gs://k8s-metrics exists"
    (
      local bucket="gs://k8s-metrics"
      local owners="k8s-infra-prow-oncall@kubernetes.io"
      local old_service_account="triage@k8s-gubernator.iam.gserviceaccount.com"

      ensure_public_gcs_bucket "${project}" "${bucket}"
      ensure_gcs_bucket_auto_deletion "${bucket}" "365" # match gs://k8s-metrics
      # GCS admins can admin all GCS buckets
      empower_gcs_admins "${project}" "${bucket}"
      # bucket owners can admin this bucket
      empower_group_to_admin_gcs_bucket "${owners}" "${bucket}"
      # k8s-infra-prow-build-trusted can write to this bucket
      principal="serviceAccount:$(svc_acct_email "k8s-infra-prow-build-trusted" "k8s-metrics")"
      ensure_gcs_role_binding "${bucket}" "${principal}" "objectAdmin"
      ensure_gcs_role_binding "${bucket}" "${principal}" "legacyBucketWriter"
      # TODO(spiffxp): this is a test to confirm we _can_ charge bigquery usage elsewhere
      #                and might prove convenient since there are datasets in this project,
      #                but this should probably not be the long-term home of usage billing
      # k8s-infra-prow-build-trusted can charge bigquery usage to this project
      ensure_project_role_binding "${project}" "${principal}" "roles/bigquery.user"
    ) 2>&1 | indent

    color 6 "Special case: ensuring gs://k8s-project-triage exists"
    (
      local bucket="gs://k8s-project-triage"
      local owners="k8s-infra-prow-oncall@kubernetes.io"
      local old_service_account="triage@k8s-gubernator.iam.gserviceaccount.com"

      ensure_public_gcs_bucket "${project}" "${bucket}"
      ensure_gcs_bucket_auto_deletion "${bucket}" "365" # match gs://k8s-metrics
      # GCS admins can admin all GCS buckets
      empower_gcs_admins "${project}" "${bucket}"
      # bucket owners can admin this bucket
      empower_group_to_admin_gcs_bucket "${owners}" "${bucket}"
      # TODO(spiffxp): remove once bindings have been removed
      # k8s-prow-builds can no longer write to this bucket
      principal="serviceAccount:${old_service_account}"
      ensure_gcs_role_binding "${bucket}" "${principal}" "objectAdmin"
      ensure_gcs_role_binding "${bucket}" "${principal}" "legacyBucketWriter"
      # k8s-infra-prow-build-trusted can write to this bucket
      principal="serviceAccount:$(svc_acct_email "k8s-infra-prow-build-trusted" "k8s-triage")"
      ensure_gcs_role_binding "${bucket}" "${principal}" "objectAdmin"
      ensure_gcs_role_binding "${bucket}" "${principal}" "legacyBucketWriter"
      # TODO(spiffxp): this is a test to confirm we _can_ charge bigquery usage elsewhere
      #                and might prove convenient since there are datasets in this project,
      #                but this should probably not be the long-term home of usage billing
      # k8s-infra-prow-build-trusted can charge bigquery usage to this project
      ensure_project_role_binding "${project}" "${principal}" "roles/bigquery.user"
    ) 2>&1 | indent
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
        cluster_args=("k8s-infra-prow-build-trusted" "${PROWJOB_POD_NAMESPACE}")
        ensure_workload_identity_serviceaccount "${svcacct_args[@]}" "${cluster_args[@]}" 2>&1 | indent

        color 6 "Ensuring DNS Updater serviceaccount"
        svcacct_args=("${project}" "k8s-infra-dns-updater" "roles/dns.admin")
        cluster_args=("k8s-infra-prow-build-trusted" "${PROWJOB_POD_NAMESPACE}")
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

    color 6 "Ensuring secrets destined for apps in 'aaa' exist in: ${project}"
    ensure_aaa_external_secrets "${project}" 2>&1 | indent

    color 6 "Ensuring prow special cases for: ${project}"
    ensure_prow_special_cases "${project}" 2>&1 | indent

    color 6 "Ensuring biquery configured for billing and access by appropriate groups in: ${project}"
    ensure_billing_bigquery "${project}" 2>&1 | indent

    color 6 "Done"
}

ensure_main_project "${PROJECT}"
