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

# This is a library of functions used to create GCP stuff.

# Setup TMPDIR before including any other functions
TMPDIR=$(mktemp -d "/tmp/k8sio-infra-gcp-lib.XXXXX")
export TMPDIR
function cleanup_tmpdir() {
  if [ "${K8S_INFRA_DEBUG:-"false"}" == "true" ]; then
    echo "K8S_INFRA_DEBUG mode, not removing tmpdir: ${TMPDIR}"
    ls -l "${TMPDIR}"
  else
    rm -rf "${TMPDIR}"
  fi
}
trap 'cleanup_tmpdir' EXIT

#
# Include sub-libraries
#

# order matters here
# - utils are used by everthing
. "$(dirname "${BASH_SOURCE[0]}")/lib_util.sh"
# - declarations in infra.yaml should be available as early as possible
. "$(dirname "${BASH_SOURCE[0]}")/lib_infra.sh"
# - iam is used by almost everything
. "$(dirname "${BASH_SOURCE[0]}")/lib_iam.sh"
# - gcs is used by gcr
. "$(dirname "${BASH_SOURCE[0]}")/lib_gcs.sh"

# order doesn't matter here, so keep sorted
. "$(dirname "${BASH_SOURCE[0]}")/lib_gcr.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib_gsm.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib_services.sh"

#
# Useful organization-wide constants
#

# The GCP org stuff needed to turn it all on.
readonly GCP_ORG="758905017065" # kubernetes.io
readonly GCP_BILLING="018801-93540E-22A20E"

# The group that admins all GCR repos.
readonly GCR_ADMINS="k8s-infra-artifact-admins@kubernetes.io"

# The group that admins all GCS buckets.
# We use the same group as GCR
readonly GCS_ADMINS="${GCR_ADMINS}"

#
# Release Engineering constants
#

# The service account name for the GCR auditor (Cloud Run runtime service
# account).
readonly AUDITOR_SVCACCT="k8s-infra-gcr-auditor"
# This is a separate service account tied to the Pub/Sub subscription that connects
# GCR Pub/Sub messages to the Cloud Run instance of the GCR auditor.
readonly AUDITOR_INVOKER_SVCACCT="k8s-infra-gcr-auditor-invoker"
# This is the Cloud Run service name of the auditor.
readonly AUDITOR_SERVICE_NAME="cip-auditor"

# The service account name for the image promoter.
readonly PROMOTER_SVCACCT="k8s-infra-gcr-promoter"

# The service account name for the image promoter's vulnerability check.
# used in: ensure-prod-storage.sh ensure-staging-storage.sh
export PROMOTER_VULN_SCANNING_SVCACCT="k8s-infra-gcr-vuln-scanning"

# Release Engineering umbrella groups
# - admins - edit and KMS access (Release Engineering subproject owners)
# - managers - access to run stage/release jobs (Patch Release Team / Branch Managers)
# - viewers - view access to Release Engineering projects (Release Manager Associates)
# used in: ensure-release-projects.sh ensure-releng.sh ensure-staging-storage.sh
export RELEASE_ADMINS="k8s-infra-release-admins@kubernetes.io"
export RELEASE_MANAGERS="k8s-infra-release-editors@kubernetes.io"
export RELEASE_VIEWERS="k8s-infra-release-viewers@kubernetes.io"

#
# Prow constants
#

# The service account email used by prow-build-trusted to trigger GCB and push to GCS
# used in: ensure-release-proejcts.sh ensure-staging-storage.sh
export GCB_BUILDER_SVCACCT="gcb-builder@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"

# used in: ensure-release-proejcts.sh ensure-staging-storage.sh
export PROW_BUILD_SERVICE_ACCOUNT="prow-build@k8s-infra-prow-build.iam.gserviceaccount.com"

# Projects hosting prow build clusters that run untrusted code, such as
# presubmits that build and test unmerged code from PRs
# shellcheck disable=SC2034 # TODO(spiffxp): can't export arrays; address when infra.yaml PR merged
readonly PROW_UNTRUSTED_BUILD_CLUSTER_PROJECTS=(
    # The google.com build cluster for prow.k8s.io
    # TODO(spiffxp): remove support for this where possible
    "k8s-prow-builds"
    # The kubernetes.io build cluster
    "$(k8s_infra_project "prow" "k8s-infra-prow-build")"
)

# Projects hosting prow build clusters that run trusted code, such as periodics
# that run merged/approved code that need access to sensitive secrets
# shellcheck disable=SC2034 # TODO(spiffxp): can't export arrays; address when infra.yaml PR merged
readonly PROW_TRUSTED_BUILD_CLUSTER_PROJECTS=(
    # The google.com trusted build cluster for prow.k8s.io
    # TODO(spiffxp): remove support for this where possible
    "k8s-prow"
    # The kubernetes.io build cluster
    "$(k8s_infra_project "prow" "k8s-infra-prow-build-trusted")"
)

# The namespace prowjobs run in; at present things are configured to use the
# same namespace across all prow build clusters. This means this value needs
# to be kept consistent across a few places:
#
# - https://git.k8s.io/test-infra/config/prow/config.yaml # pod_namespace: test-pods
# - infra/gcp/clusters/projects/k8s-infra-prow-*/*/main.tf # pod_namespace = test-pods
# # TODO: not all resources belong in test-pods, would be good to shard into folders
# - infra/gcp/clusters/projects/k8s-infra-prow-*/*/resources/* # namespace: test-pods
# used in: ensure-gsuite.sh ensure-main-project.sh ensure-prod-storage.sh ensure-staging-storage.sh
export PROWJOB_POD_NAMESPACE="test-pods"

#
# Functions
#

# Get the service account email for a given short name
# $1: The GCP project
# $2: The name
function svc_acct_email() {
    if [ $# != 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "svc_acct_email(project, name) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local name="$2"

    echo "${name}@${project}.iam.gserviceaccount.com"
}

# Get the cloud build service account email for a given project
#   ref: https://cloud.google.com/cloud-build/docs/securing-builds/configure-access-control#service_account
# $1 The GCP project
function gcb_service_account_email() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "gcb_service_account_email(project) requires 1 argument" >&2
        return 1
    fi
    local project="$1"
    gcloud projects get-iam-policy "${project}" \
      --flatten="bindings[].members"\
      --filter="bindings.role:roles/cloudbuild.builds.builder AND bindings.members ~ serviceAccount:[0-9]+@cloudbuild" \
      --format="value(bindings.members)" |\
      sed -e 's/^serviceAccount://'
}

# Ensure that a project exists in our org and has fundamental configurations as
# we want them (e.g. billing).
# $1: The GCP project
function ensure_project() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "ensure_project(project) requires 1 argument" >&2
        return 1
    fi
    local project="$1"
    local account
    local org

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
        if [ "${org}" != "${GCP_ORG}" ]; then
            echo "project ${project} exists, but not in our org: got ${org}" >&2
            return 2
        fi
    fi

    # Avoid calling link if not needed, so accounts with project ownership but
    # without billing privileges can still run scripts that use this function
    # to manage projects that have already been provisioned
    account=$(gcloud beta billing projects describe "${project}" --format="value(billingAccountName)")
    if [ "${account}" != "billingAccounts/${GCP_BILLING}" ]; then
        gcloud beta billing projects link "${project}" \
            --billing-account "${GCP_BILLING}"
    fi

    # Ensure projects are not owned by users; they should be owned by groups.
    # If this is being run by a user, and project creation happened above,
    # this will remove the roles/owner binding that was implicitly created.
    # It is acceptable if this results in no direct project ownership, as we
    # have ownership propgating down from parent resources (folders, org, etc)
    while read -r user; do
        # But OK one special case for now: leave @kubernetes.io users alone,
        # we have one setup to own k8s-gsuite, we may find we need others
        if ! (echo "${user}" | grep -q "@kubernetes.io$"); then
            ensure_removed_project_role_binding "${project}" "${user}" "roles/owner"
        fi
    done < <(gcloud projects get-iam-policy "${project}" \
        --flatten="bindings[].members" \
        --filter="bindings.role=roles/owner AND bindings.members ~ ^user:" \
        --format="value(bindings.members)")
}

# Grant project viewer privileges to a principal
# $1: The GCP project
# $2: The group email
function empower_group_as_viewer() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_group_as_viewer(project, group) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local group="$2"

    ensure_project_role_binding "${project}" "group:${group}" "roles/viewer"
}

# Grant roles for running cip-auditor E2E test
# (https://github.com/kubernetes-sigs/k8s-container-image-promoter/tree/master/test-e2e#cip-auditor-cip-auditor-e2ego).

# $1: The GCP project
# $2: The service account
function empower_service_account_for_cip_auditor_e2e_tester() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_service_account_for_cip_auditor_e2e_tester(acct, project) requires 2 arguments" >&2
        return 1
    fi
    local acct="$1"
    local project="$2"

    local roles=(
        roles/errorreporting.admin
        roles/logging.admin
        roles/pubsub.admin
        roles/resourcemanager.projectIamAdmin
        roles/run.admin
        roles/serverless.serviceAgent
        roles/storage.admin
    )

    for role in "${roles[@]}"; do
        ensure_project_role_binding "${project}" "serviceAccount:${acct}" "${role}"
    done
}

# Grant GCB admin privileges to a principal
# $1: The GCP project
# $2: The group email
function empower_group_for_gcb() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_group_for_gcb(project, group) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local group="$2"

    local roles=(
        roles/cloudbuild.builds.editor
        # TODO(justaugustus/thockin): This only exists to grant the
        #      serviceusage.services.use permission allow writers access to execute
        #      Cloud Builds. We should refactor this once we develop custom roles.
        #
        #      Ref: https://cloud.google.com/storage/docs/access-control/iam-console
        roles/serviceusage.serviceUsageConsumer
    )
    for role in "${roles[@]}"; do
        ensure_project_role_binding "${project}" "group:${group}" "${role}"
    done
}

# Grant KMS admin privileges to a principal
# $1: The GCP project
# $2: The group email
function empower_group_for_kms() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_group_for_kms(project, group) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local group="$2"

    local roles=(
        roles/cloudkms.admin
        roles/cloudkms.cryptoKeyEncrypterDecrypter
    )

    for role in "${roles[@]}"; do
        ensure_project_role_binding "${project}" "group:${group}" "${role}"
    done
}

# Grant full privileges to GCR admins
# $1: The GCP project
# $2: The GCR region (optional)
function empower_gcr_admins() {
    if [ $# -lt 1 ] || [ $# -gt 2 ] || [ -z "$1" ]; then
        echo "empower_gcr_admins(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local region="${2:-}"
    local bucket
    bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    ensure_project_role_binding "${project}" "group:${GCR_ADMINS}" "roles/viewer"
    empower_group_to_admin_gcs_bucket "${GCR_ADMINS}" "${bucket}"
}

# Grant full privileges to GCS admins
# $1: The GCP project
# $2: The bucket
function empower_gcs_admins() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "empower_gcs_admins(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    local project="${1}"
    local bucket="${2}"

    ensure_project_role_binding "${project}" "group:${GCS_ADMINS}" "roles/viewer"
    empower_group_to_admin_gcs_bucket "${GCS_ADMINS}" "${bucket}"
}

# Grant Cloud Run privileges to a group.
# $1: The GCP project
# $2: The googlegroups group
function empower_group_to_admin_artifact_auditor() {
    if [ $# != 2 ]; then
        echo "empower_group_to_admin_artifact_auditor(project, group_name) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local group="$2"
    local acct
    acct=$(svc_acct_email "${project}" "${AUDITOR_SVCACCT}")

    local roles=(
        # Grant privileges to deploy the auditor Cloud Run service. See
        # https://cloud.google.com/run/docs/reference/iam/roles#additional-configuration.
        roles/run.admin
        # To read auditor's logs, we need serviceusage.services.use
        roles/serviceusage.serviceUsageConsumer
        # Also grant privileges to resolve Stackdriver Error Reporting errors.
        roles/errorreporting.user
    )

    for role in "${roles[@]}"; do
        ensure_project_role_binding "${project}" "group:${group}" "${role}"
    done

    gcloud \
        --project="${project}" \
        iam service-accounts add-iam-policy-binding \
        "${acct}" \
        --member="group:${group}" \
        --role="roles/iam.serviceAccountUser"
}

# Grant full privileges to the GCR promoter bot
# $1: The GCP project
# $2: The GCR region (optional)
function empower_artifact_promoter() {
    if [ $# -lt 1 ] || [ $# -gt 2 ] || [ -z "$1" ]; then
        echo "empower_artifact_promoter(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local region="${2:-}"
    local acct=
    acct=$(svc_acct_email "${project}" "${PROMOTER_SVCACCT}")

    if ! gcloud --project "${project}" iam service-accounts describe "${acct}" >/dev/null 2>&1; then
        gcloud --project "${project}" \
            iam service-accounts create \
            "${PROMOTER_SVCACCT}" \
            --display-name="k8s-infra container image promoter"
    fi

    empower_svcacct_to_admin_gcr "${acct}" "${project}" "${region}"
}

# Ensure the auditor service account exists and has the ability to write logs and fire alerts to Stackdriver Error Reporting.
# $1: The GCP project
function empower_artifact_auditor() {
    if [ $# -lt 1 ] || [ -z "$1" ]; then
        echo "empower_artifact_auditor(project) requires 1 argument" >&2
        return 1
    fi
    local project="$1"

    local roles=(
        # Allow auditor to write logs.
        roles/logging.logWriter
        # Allow auditor to write Stackdriver Error Reporting alerts.
        roles/errorreporting.writer
        # No other permissions are necessary because the cip-auditor process in the
        # Cloud Run instance running as this service account will read the
        # production GCR which is already world-readable.
    )

    local acct
    acct=$(svc_acct_email "${project}" "${AUDITOR_SVCACCT}")

    if ! gcloud --project "${project}" iam service-accounts describe "${acct}" >/dev/null 2>&1; then
        gcloud --project "${project}" \
            iam service-accounts create \
            "${AUDITOR_SVCACCT}" \
            --display-name="k8s-infra container image auditor"
    fi

    for role in "${roles[@]}"; do
        ensure_project_role_binding "${project}" "serviceAccount:${acct}" "${role}"
    done
}

# Ensure the artifact auditor invoker service account exists and has the ability
# to invoke the auditor service. The auditor invoker service account is tied to
# the Pub/Sub subscription that triggers the Cloud Run instance (the
# subscription getting its messages from the GCR topic "gcr", where changes to
# GCR are posted).
# $1: The GCP project
function empower_artifact_auditor_invoker() {
    if [ $# -lt 1 ] || [ -z "$1" ]; then
        echo "empower_artifact_auditor_invoker(project) requires 1 argument" >&2
        return 1
    fi
    local project="$1"

    local acct
    acct=$(svc_acct_email "${project}" "${AUDITOR_INVOKER_SVCACCT}")

    if ! gcloud --project "${project}" iam service-accounts describe "${acct}" >/dev/null 2>&1; then
        gcloud --project "${project}" \
            iam service-accounts create \
            "${AUDITOR_INVOKER_SVCACCT}" \
            --display-name="k8s-infra container image auditor invoker"
    fi

    # Allow it to invoke the specific auditor Cloud Run service.
    gcloud \
        run \
        services \
        add-iam-policy-binding \
        "${AUDITOR_SERVICE_NAME}" \
        --member="serviceAccount:${acct}" \
        --role=roles/run.invoker \
        --platform=managed \
        --project="${project}" \
        --region=us-central1
}

# Ensure that DNS managed zone exists, creating one if need.
# $1 The GCP project
# $2 The managed zone name (e.g. kubernetes-io)
# $3 The DNS zone name (e.g. kubernetes.io)
function ensure_dns_zone() {
    if [ $# != 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "ensure_dns_zone(project, zone_name, dns_name) requires 3 arguments" >&2
        return 1
    fi
    local project="$1"
    local zone_name="$2"
    local dns_name="$3"

  if ! gcloud --project "${project}" dns managed-zones describe "${zone_name}" >/dev/null 2>&1; then
      gcloud --project "${project}" \
        dns managed-zone create \
        "${zone_name}" \
        --dns-name "${dns_name}"
  fi
}

# Allow GKE clusters in the given GCP project to run workloads using a
# Kubernetes service account in the given namepsace to act as the given
# GCP service account via Workload Identity when the name of the Kubernetes
# service account matches the optionally provided name if given, or the
# name of the GCP service account.
#
# ref: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
#
# $1:   The GCP project that hosts the GKE clusters (e.g. k8s-infra-foo-clusters)
# $2:   The K8s namespace that hosts the Kubernetes service account (e.g. my-app-ns)
# $3:   The GCP service account to be bound (e.g. k8s-infra-doer@k8s-infra-foo.iam.gserviceaccount.com)
# [$4]: Optional: The Kubernetes service account name (e.g. my-app-doer; default e.g. k8s-infra-doer)
#
# e.g. the above allows pods running as my-app-ns/my-app-doer in clusters in
#      k8s-infra-foo-clusters to act as k8s-infra-doer@k8s-infra-foo.iam.gserviceaccount.com
function empower_gke_for_serviceaccount() {
    if [ $# -lt 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "${FUNCNAME[0]}(gcp_project, k8s_namespace, gcp_sa_email, [k8s_sa_name]) requires at least 3 arguments" >&2
        return 1
    fi

    local gke_project="$1"
    local k8s_namespace="$2"
    local gcp_sa_email="${3}"
    local k8s_sa_name="${4:-""}"
    if [ -z "${k8s_sa_name}" ]; then
      k8s_sa_name="$(echo "${gcp_sa_email}" | cut -d@ -f1)"
    fi

    local principal="serviceAccount:${gke_project}.svc.id.goog[${k8s_namespace}/${k8s_sa_name}]"

    ensure_serviceaccount_role_binding "${gcp_sa_email}" "${principal}" "roles/iam.workloadIdentityUser"
}

# Prevent clusters in the given GCP project from running workloads using a
# Kubernetes service account in the given namespace to act as the given
# GCP service account. aka the opposite of empower_gke_for_serviceaccount
#
# $1:   The GCP project that hosts the GKE clusters (e.g. k8s-infra-foo-clusters)
# $2:   The K8s namespace that hosts the Kubernetes service account (e.g. my-app-ns)
# $3:   The GCP service account to be unbound (e.g. k8s-infra-doer@k8s-infra-foo.iam.gserviceaccount.com)
# [$4]: Optional: The Kubernetes service account name (e.g. my-app-doer; default: k8s-infra-doer)
function unempower_gke_for_serviceaccount() {
    if [ $# -lt 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "${FUNCNAME[0]}(gcp_project, k8s_namespace, gcp_sa_email, [k8s_sa_name]) requires at least 3 arguments" >&2
        return 1
    fi

    local gke_project="$1"
    local k8s_namespace="$2"
    local gcp_sa_email="${3}"
    local k8s_sa_name="${4:-""}"
    if [ -z "${k8s_sa_name}" ]; then
      k8s_sa_name="$(echo "${gcp_sa_email}" | cut -d@ -f1)"
    fi

    local principal="serviceAccount:${gke_project}.svc.id.goog[${k8s_namespace}/${k8s_sa_name}]"

    ensure_removed_serviceaccount_role_binding "${gcp_sa_email}" "${principal}" "roles/iam.workloadIdentityUser"
}

# Ensure that a global ip address exists, creating one if needed
# $1 The GCP project
# $2 The address name (e.g. foo-ingress), IPv6 addresses must have a "-v6" suffix
# $3 The address description (e.g. "IP address for the foo GCLB")
function ensure_global_address() {
    if [ ! $# -eq 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "ensure_global_address(gcp_project, name, description) requires 3 arguments" >&2
        return 1
    fi

    local gcp_project="$1"
    local name="$2"
    local description="$3"

    local ip_version="IPV4"
    local re='[a-zA-Z0-9_.-]+-v6$'
    if [[ $name =~ $re ]]; then
        local ip_version="IPV6"
    fi

    if ! gcloud --project "${gcp_project}" compute addresses describe "${name}" --global >/dev/null 2>&1; then
      gcloud --project "${gcp_project}" \
        compute addresses create \
        "${name}" \
        --description="${description}" \
        --ip-version="${ip_version}" \
        --global
    fi
}

# Ensure that a regional ip address exists, creating one if needed
# $1 The GCP project
# $2 The region (e.g. us-central1)
# $3 The address name (e.g. foo-ingress)
# $4 The address description (e.g. "IP address for the foo GCLB")
function ensure_regional_address() {
    if [ ! $# -eq 4 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
        echo "ensure_regional_address(gcp_project, region, name, description) requires 4 arguments" >&2
        return 1
    fi

    local gcp_project="$1"
    local region="$2"
    local name="$3"
    local description="$4"

    if ! gcloud --project "${gcp_project}" compute addresses describe "${name}" --region="${region}" >/dev/null 2>&1; then
      gcloud --project "${gcp_project}" \
        compute addresses create \
        "${name}" \
        --description="${description}" \
        --region="${region}"
    fi
}
