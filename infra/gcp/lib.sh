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

. "$(dirname "${BASH_SOURCE[0]}")/lib_util.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib_gcs.sh"

# The group that admins all GCR repos.
GCR_ADMINS="k8s-infra-artifact-admins@kubernetes.io"

# The group that admins all GCS buckets.
# We use the same group as GCR
GCS_ADMINS=$GCR_ADMINS

# The service account name for the image promoter.
PROMOTER_SVCACCT="k8s-infra-gcr-promoter"

# The service account name for the GCR auditor (Cloud Run runtime service
# account).
AUDITOR_SVCACCT="k8s-infra-gcr-auditor"
# This is a separate service account tied to the Pub/Sub subscription that connects
# GCR Pub/Sub messages to the Cloud Run instance of the GCR auditor.
AUDITOR_INVOKER_SVCACCT="k8s-infra-gcr-auditor-invoker"
# This is the Cloud Run service name of the auditor.
AUDITOR_SERVICE_NAME="cip-auditor"

# The service account email for Prow (not in this org for now).
PROW_SVCACCT="deployer@k8s-prow.iam.gserviceaccount.com"

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

# Grant roles for running cip-auditor E2E test
# (https://github.com/kubernetes-sigs/k8s-container-image-promoter/tree/master/test-e2e#cip-auditor-cip-auditor-e2ego).

# $1: The GCP project
# $2: The service account
function empower_service_account_for_cip_auditor_e2e_tester() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_service_account_for_cip_auditor_e2e_tester(acct, project) requires 2 arguments" >&2
        return 1
    fi
    acct="$1"
    project="$2"

    roles=(
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

# Grant GCB admin privileges to a principal
# $1: The GCP project
# $2: The group email
function empower_group_for_gcb() {
    if [ $# -lt 2 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_for_gcb(project, group) requires 2 arguments" >&2
        return 1
    fi
    project="$1"
    group="$2"

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
    project="$1"
    group="$2"

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
    project="${1}"
    bucket="${2}"

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
    project="$1"
    group="$2"
    acct=$(svc_acct_email "${project}" "${AUDITOR_SVCACCT}")

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

    empower_svcacct_to_admin_gcr "${acct}" "${project}" "${region}"
}

# Grant GCR write privileges to a group
# $1: The googlegroups group email
# $2: The GCP project
# $3: The GCR region (optional)
function empower_group_to_write_gcr() {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "empower_group_to_write_gcr(group_name, project, [region]) requires 2 or 3 arguments" >&2
        return 1
    fi
    group="$1"
    project="$2"
    region="${3:-}"
    bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    empower_group_to_write_gcs_bucket "${group}" "${bucket}"
}

# Grant GCR admin privileges to a service account in a project/region.
# $1: The GCP service account email
# $2: The GCP project
# $3: The GCR region (optional)
function empower_svcacct_to_admin_gcr () {
    if [ $# -lt 2 -o $# -gt 3 -o -z "$1" -o -z "$2" ]; then
        echo "empower_svcacct_to_admin_gcr(acct, project, [region]) requires 2 or 3 arguments" >&2
        return 1
    fi
    acct="$1"
    project="$2"
    region="${3:-}"
    bucket=$(gcs_bucket_for_gcr "${project}" "${region}")

    empower_svcacct_to_admin_gcs_bucket "${group}" "${bucket}"
}

# Ensure the auditor service account exists and has the ability to write logs and fire alerts to Stackdriver Error Reporting.
# $1: The GCP project
function empower_artifact_auditor() {
    if [ $# -lt 1 -o -z "$1" ]; then
        echo "empower_artifact_auditor(project) requires 1 argument" >&2
        return 1
    fi
    project="$1"

    acct=$(svc_acct_email "${project}" "${AUDITOR_SVCACCT}")

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
    project="$1"

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

# Ensure that DNS managed zone exists, creating one if need.
# $1 The GCP project
# $2 The managed zone name (e.g. kubernetes-io)
# $3 The DNS zone name (e.g. kubernetes.io)
function ensure_dns_zone() {
    if [ $# != 3 -o -z "$1" -o -z "$2" -o -x "$3" ]; then
        echo "ensure_dns_zone(project, zone_name, dns_name) requires 3 arguments" >&2
        return 1
    fi
    project="$1"
    zone_name="$2"
    dns_name="$3"

  if ! gcloud --project "${project}" dns managed-zones describe "${zone_name}" >/dev/null 2>&1; then
      gcloud --project "${project}" \
        dns managed-zone create \
        "${zone_name}" \
        --dns-name "${dns_name}"
  fi
}
