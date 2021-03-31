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

. "$(dirname "${BASH_SOURCE[0]}")/lib_util.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib_iam.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib_gcr.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib_gcs.sh"

# The group that admins all GCR repos.
GCR_ADMINS="k8s-infra-artifact-admins@kubernetes.io"

# The group that admins all GCS buckets.
# We use the same group as GCR
GCS_ADMINS=$GCR_ADMINS

# The service account name for the image promoter.
PROMOTER_SVCACCT="k8s-infra-gcr-promoter"

# The service account name for the image promoter's vulnerability check.
PROMOTER_VULN_SCANNING_SVCACCT="k8s-infra-gcr-vuln-scanning"

# The service account name for the GCR auditor (Cloud Run runtime service
# account).
AUDITOR_SVCACCT="k8s-infra-gcr-auditor"
# This is a separate service account tied to the Pub/Sub subscription that connects
# GCR Pub/Sub messages to the Cloud Run instance of the GCR auditor.
AUDITOR_INVOKER_SVCACCT="k8s-infra-gcr-auditor-invoker"
# This is the Cloud Run service name of the auditor.
AUDITOR_SERVICE_NAME="cip-auditor"

# TODO: decommission this once we've flipped to prow-build-trusted
# The service account email for Prow (not in this org for now).
PROW_SVCACCT="deployer@k8s-prow.iam.gserviceaccount.com"
# The service account email used by prow-build-trusted to trigger GCB and push to GCS
GCB_BUILDER_SVCACCT="gcb-builder@k8s-infra-prow-build-trusted.iam.gserviceaccount.com"

# The GCP org stuff needed to turn it all on.
GCP_ORG="758905017065" # kubernetes.io
GCP_BILLING="018801-93540E-22A20E"

# Release Engineering umbrella groups
# - admins - edit and KMS access (Release Engineering subproject owners)
# - managers - access to run stage/release jobs (Patch Release Team / Branch Managers)
# - viewers - view access to Release Engineering projects (Release Manager Associates)
RELEASE_ADMINS="k8s-infra-release-admins@kubernetes.io"
RELEASE_MANAGERS="k8s-infra-release-editors@kubernetes.io"
RELEASE_VIEWERS="k8s-infra-release-viewers@kubernetes.io"

# Get the service account email for a given short name
# $1: The GCP project
# $2: The name
function svc_acct_email() {
    if [ $# != 2 -o -z "$1" -o -z "$2" ]; then
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
    if [ $# != 1 -o -z "$1" ]; then
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
    if [ $# != 1 -o -z "$1" ]; then
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

# Enable an API
# $1: The GCP project
# $2: The API (e.g. containerregistry.googleapis.com)
function enable_api() {
    if [ $# != 2 -o -z "$1" -o -z "$2" ]; then
        echo "enable_api(project, api) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local api="$2"

    gcloud --project "${project}" services enable "${api}"
}

# Grant project viewer privileges to a principal
# $1: The GCP project
# $2: The group email
function empower_group_as_viewer() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_as_viewer(project, group) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local group="$2"

    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${group}" \
        --role roles/viewer
}

# Grant roles for running cip-auditor E2E test
# (https://github.com/kubernetes-sigs/k8s-container-image-promoter/tree/master/test-e2e#cip-auditor-cip-auditor-e2ego).

# $1: The GCP project
# $2: The service account
function empower_service_account_for_cip_auditor_e2e_tester() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
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
        gcloud \
            projects add-iam-policy-binding "${project}" \
            --member "serviceAccount:${acct}" \
            --role "${role}"
    done
}

# Grant roles for running pull-cip-vuln
# $1: The service account
# $2: The GCP Project
function empower_service_account_for_cip_vuln_scanning() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_service_account_for_cip_vuln_scanning(acct, project) requires 2 arguments" >&2
        return 1
    fi
    local acct="$1"
    local project="$2"

    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "serviceAccount:${acct}" \
        --role roles/containeranalysis.occurrences.viewer
}

# Grant GCB admin privileges to a principal
# $1: The GCP project
# $2: The group email
function empower_group_for_gcb() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_for_gcb(project, group) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local group="$2"

    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${group}" \
        --role roles/cloudbuild.builds.editor

    # TODO(justaugustus/thockin): This only exists to grant the
    #      serviceusage.services.use permission allow writers access to execute
    #      Cloud Builds. We should refactor this once we develop custom roles.
    #
    #      Ref: https://cloud.google.com/storage/docs/access-control/iam-console
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${group}" \
        --role roles/serviceusage.serviceUsageConsumer
}

# Grant KMS admin privileges to a principal
# $1: The GCP project
# $2: The group email
function empower_group_for_kms() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_for_kms(project, group) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local group="$2"

    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${group}" \
        --role roles/cloudkms.admin

    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${group}" \
        --role roles/cloudkms.cryptoKeyEncrypterDecrypter
}

# Grant privileges to prow in a staging project
# $1: The GCP project
# $2: The GCS scratch bucket
function empower_prow() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_prow(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local bucket="$2"

    # commands are copy-pasted so that one set can turn into deletes
    # when we're ready to decommission PROW_SVCACCT

    # Allow prow to trigger builds.
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "serviceAccount:${PROW_SVCACCT}" \
        --role roles/cloudbuild.builds.builder
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "serviceAccount:${GCB_BUILDER_SVCACCT}" \
        --role roles/cloudbuild.builds.builder

    # Allow prow to push source and access build logs.
    gsutil iam ch \
        "serviceAccount:${PROW_SVCACCT}:objectCreator" \
        "${bucket}"
    gsutil iam ch \
        "serviceAccount:${PROW_SVCACCT}:objectViewer" \
        "${bucket}"
    gsutil iam ch \
        "serviceAccount:${GCB_BUILDER_SVCACCT}:objectCreator" \
        "${bucket}"
    gsutil iam ch \
        "serviceAccount:${GCB_BUILDER_SVCACCT}:objectViewer" \
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
    local project="$1"
    local region="${2:-}"
    local bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    empower_group_as_viewer "${project}" "${GCR_ADMINS}"
    empower_group_to_admin_gcs_bucket "${GCR_ADMINS}" "${bucket}"
}

# Grant full privileges to GCS admins
# $1: The GCP project
# $2: The bucket
function empower_gcs_admins() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_gcs_admins(project, bucket) requires 2 arguments" >&2
        return 1
    fi
    local project="${1}"
    local bucket="${2}"

    empower_group_as_viewer "${project}" "${GCS_ADMINS}"
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
    local acct=$(svc_acct_email "${project}" "${AUDITOR_SVCACCT}")

    # Grant privileges to deploy the auditor Cloud Run service. See
    # https://cloud.google.com/run/docs/reference/iam/roles#additional-configuration.
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${group}" \
        --role roles/run.admin
    # To read auditor's logs, we need serviceusage.services.use
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${group}" \
        --role roles/serviceusage.serviceUsageConsumer
    gcloud \
        --project="${project}" \
        iam service-accounts add-iam-policy-binding \
        "${acct}" \
        --member="group:${group}" \
        --role="roles/iam.serviceAccountUser"
    # Also grant privileges to resolve Stackdriver Error Reporting errors.
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "group:${group}" \
        --role roles/errorreporting.user
}

# Grant full privileges to the GCR promoter bot
# $1: The GCP project
# $2: The GCR region (optional)
function empower_artifact_promoter() {
    if [ $# -lt 1 -o $# -gt 2 -o -z "$1" ]; then
        echo "empower_artifact_promoter(project, [region]) requires 1 or 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local region="${2:-}"

    local acct=$(svc_acct_email "${project}" "${PROMOTER_SVCACCT}")

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
    if [ $# -lt 1 -o -z "$1" ]; then
        echo "empower_artifact_auditor(project) requires 1 argument" >&2
        return 1
    fi
    local project="$1"

    local acct=$(svc_acct_email "${project}" "${AUDITOR_SVCACCT}")

    if ! gcloud --project "${project}" iam service-accounts describe "${acct}" >/dev/null 2>&1; then
        gcloud --project "${project}" \
            iam service-accounts create \
            "${AUDITOR_SVCACCT}" \
            --display-name="k8s-infra container image auditor"
    fi

    # Allow auditor to write logs.
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "serviceAccount:${acct}" \
        --role roles/logging.logWriter

    # Allow auditor to write Stackdriver Error Reporting alerts.
    gcloud \
        projects add-iam-policy-binding "${project}" \
        --member "serviceAccount:${acct}" \
        --role roles/errorreporting.writer

    # No other permissions are necessary because the cip-auditor process in the
    # Cloud Run instance running as this service account will read the
    # production GCR which is already world-readable.
}

# Ensure the artifact auditor invoker service account exists and has the ability
# to invoke the auditor service. The auditor invoker service account is tied to
# the Pub/Sub subscription that triggers the Cloud Run instance (the
# subscription getting its messages from the GCR topic "gcr", where changes to
# GCR are posted).
# $1: The GCP project
function empower_artifact_auditor_invoker() {
    if [ $# -lt 1 -o -z "$1" ]; then
        echo "empower_artifact_auditor_invoker(project) requires 1 argument" >&2
        return 1
    fi
    local project="$1"

    local acct=$(svc_acct_email "${project}" "${AUDITOR_INVOKER_SVCACCT}")

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

# Create a service account
# $1: The GCP project
# $2: The account name (e.g. "foo-manager")
# $3: The account display-name (e.g. "Manages all foo")
function ensure_service_account() {
    if [ $# != 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "ensure_service_account(project, name, display_name) requires 3 arguments" >&2
        return 1
    fi
    local project="$1"
    local name="$2"
    local display_name="$3"

    local acct=$(svc_acct_email "${project}" "${name}")

    if ! gcloud --project "${project}" iam service-accounts describe "${acct}" >/dev/null 2>&1; then
        gcloud --project "${project}" \
            iam service-accounts create \
            "${name}" \
            --display-name="${display_name}"
    fi
}

# Ensure that DNS managed zone exists, creating one if need.
# $1 The GCP project
# $2 The managed zone name (e.g. kubernetes-io)
# $3 The DNS zone name (e.g. kubernetes.io)
function ensure_dns_zone() {
    if [ $# != 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
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

# Allow a Kubernetes service account (KSA) the ability to authenticate as the as
# the given GCP service account for the given GKE Project's Kubernetes
# namespace; this is also called Workload Identity.
#
# $1: The service account scoped to a (1) GKE project, (2) K8s namespace, and
#     (3) K8s service account. The format is currently
#
#       "${gke_project}.svc.id.goog[${k8s_namespace}/${k8s_svcacct}]"
#
#     This is used to scope the grant of permissions to the combination of the
#     above 3 variables
# $2: The GCP project that owns the GCP service account.
# $3: The GCP service account to draw powers from.
function empower_ksa_to_svcacct() {
    if [ ! $# -eq 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "empower_ksa_to_svcacct(ksa_scope, gcp_project, gcp_scvacct) requires 3 arguments" >&2
        return 1
    fi

    local ksa_scope="$1"
    local gcp_project="$2"
    local gcp_svcacct="$3"

    gcloud iam service-accounts add-iam-policy-binding \
        --role roles/iam.workloadIdentityUser \
        --member "serviceAccount:${ksa_scope}" \
        "${gcp_svcacct}" \
        --project="${gcp_project}"
}

# Ensure that a global ip address exists, creating one if needed
# $1 The GCP project
# $2 The address name (e.g. foo-ingress), IPv6 addresses must have a "-v6" suffix
# $3 The address description (e.g. "IP address for the foo GCLB")
function ensure_global_address() {
    if [ ! $# -eq 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
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
    if [ ! $# -eq 4 -o -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
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

# Output a plan of services to enable/disable for a given gcp project; format
# is YAML, each key is a list of services e.g. [pubsub.googleapis.com, ...]
#   intent:     # services we wish to enable
#   enabled:    # services that are presently enabled
#   expected:   # intent + any services directly depended on by intent
#   to_enable:  # services in intent that are not enabled
#   to_disable: # services that are enabled but not in expected
# $1  The GCP project
# $2+ Service names that are expected to be enabled (e.g. pubsub.googleapis.com)
function _plan_enabled_services() {
    if [ $# -lt 2 -o -z "$1" ]; then
        echo "list_services(gcp_project, service...) requires at least 2 arguments" >&2
        return 1
    fi

    local gcp_project="$1"; shift

    gcloud services list --enabled --project="${gcp_project}" \
      --format='yaml(config.name,dependencyConfig.directlyDependsOn)' \
      | yq --slurp -y --args '($ARGS.positional | sort) as $intent | {
        intent: $intent,
        enabled: map(.config.name) | sort,
        expected: (
          map(
            select([.config.name] | inside($intent))
            | (.dependencyConfig?.directlyDependsOn // [])
          ) + $intent
        )
        | flatten
        | map({key:., value:true}) | from_entries | keys | sort
      } | . += {
        to_enable: (.expected - .enabled),
        to_disable: (.enabled - .expected)
      }' "$@"
}

# Ensure that only the given services and their direct dependencies are enabled; disable any other services
# $1  The GCP project for which to enable/disable services
# $2+ The service names (e.g. pubsub.googleapis.com)
function ensure_only_services() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_only_services(gcp_project, service...) requires at least 2 arguments" >&2
        return 1
    fi

    local gcp_project="$1"; shift

    local tmp_dir
    tmp_dir=$(mktemp -d "/tmp/k8sio-infra-gcp-lib.XXXXX")
    # tmp_dir is local but trap is global, so expand now to avoid unbound variable on exit
    # shellcheck disable=SC2064
    trap "rm -rf ${tmp_dir}" EXIT

    local before="${tmp_dir}/ensure-only-services.before.yaml"
    local after_enable="${tmp_dir}/ensure-only-services.after_enable.yaml"
    local after_disable="${tmp_dir}/ensure-only-services.after_disable.yaml"

    # get services before modifying to diff against when finished
    _plan_enabled_services "${gcp_project}" "$@" > "${before}"

    # if there's nothing to do, return early
    if ! <"${before}" yq --exit-status '[.to_enable, .to_disable] | map (length > 0) | any' >/dev/null; then
      return
    fi

    echo "plan to enable/disable the following services"
    <"${before}" yq -y '{to_enable, to_disable}'

    # enable services that need to be enabled
    for service in $(<"${before}" yq -r '.to_enable[]'); do
        gcloud services enable --project="${gcp_project}" "${service}"
    done

    # disable services not explicitly enabled or directly required
    _plan_enabled_services "${gcp_project}" "$@" > "${after_enable}"


    # TODO(spiffxp): get comfortable with --force or redo to disable in dep-order;
    #                until then, set an obnoxiously long env var to actually disable
    local disable_cmd='echo "INFO: dry-run mode, would run:" gcloud'
    if [ "${K8S_INFRA_ENSURE_ONLY_SERVICES_WILL_FORCE_DISABLE:-""}" == "true" ]; then
        disable_cmd=gcloud
    fi
    for service in $( (<"${after_enable}" yq -r '.to_disable[]') | sort | uniq -u); do
        ${disable_cmd} services disable --force "${service}" --project="${gcp_project}"
    done

    _plan_enabled_services "${gcp_project}" "$@" > "${after_disable}"

    # in the event that an enable/disable cycle doesn't do enough, let's warn
    if <"${after_disable}" yq --exit-status '[.to_enable, .to_disable] | map (length > 0) | any' >/dev/null; then
      echo "WARN: ensure_only_services: after enable/disable cycle, still projects to enable/disable: ${gcp_project}"
      cat "${after_disable}"
    fi

    diff_colorized "${before}" "${after_disable}"
}
