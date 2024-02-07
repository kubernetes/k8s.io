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

# This script is used to create a new "staging" repo in GCR, and a bucket in GCS.
#
# Each sub-project that needs to publish artifacts should have their
# own staging GCR repo & GCS bucket.
#
# Each staging bucket & repo exists in its own GCP project, and is writable by a
# dedicated googlegroup.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
	echo "usage: $0 [repo...]" >/dev/stderr
	echo "example:" >/dev/stderr
	echo "  $0 # do all staging repos" >/dev/stderr
	echo "  $0 coredns # just do one" >/dev/stderr
	echo >/dev/stderr
}

#
# Staging project configuration
#
mapfile -t STAGING_PROJECTS < <(k8s_infra_projects "staging")
readonly STAGING_PROJECTS

readonly RELEASE_STAGING_PROJECTS=(
    "$(k8s_infra_project staging k8s-staging-artifact-promoter)"
    "$(k8s_infra_project staging k8s-staging-build-image)"
    "$(k8s_infra_project staging k8s-staging-ci-images)"
    "$(k8s_infra_project staging k8s-staging-cip-test)"
    "$(k8s_infra_project staging k8s-staging-experimental)"
    "$(k8s_infra_project staging k8s-staging-kubernetes)"
    "$(k8s_infra_project staging k8s-staging-releng)"
    "$(k8s_infra_project staging k8s-staging-releng-test)"
    "$(k8s_infra_project staging k8s-staging-publishing-bot)"
)

readonly STAGING_PROJECT_SERVICES=(
    # used by the staging project to host container images in Artifact Registry
    artifactregistry.googleapis.com
    # used by the staging project to inventory GCP resources
    cloudasset.googleapis.com
    # used by the staging project use GCB to build/sign/push images to AR/GCR
    cloudbuild.googleapis.com
    # Some Google CloudBuild jobs may use KMS
    cloudkms.googleapis.com
    # These projects host images in GCR
    containerregistry.googleapis.com
    # used by cloudbuild to run jobs with dedicated service accounts
    iam.googleapis.com
    # Some GCB jobs may use Secret Manager (preferred over KMS)
    secretmanager.googleapis.com
    # used by the staging project to troobleshoot
    policytroubleshooter.googleapis.com
    # These projects may host binaries in GCS
    storage-component.googleapis.com

    # Dependencies (gcloud services used to encode these in its response)

    # logging used by: cloudbuild
    logging.googleapis.com
    # pubsub used by: cloudbuild, containerregistry
    pubsub.googleapis.com
    # storage-api used by: cloudbuild, containerregistry
    storage-api.googleapis.com
    # used by cloudbuild for keyless artifact signing
    iamcredentials.googleapis.com
)

readonly STAGING_PROJECT_DISABLED_SERVICES=(
    # Disabled per https://github.com/kubernetes/k8s.io/issues/1963
    containeranalysis.googleapis.com
    # Disabled per https://github.com/kubernetes/k8s.io/issues/1963
    containerscanning.googleapis.com
)

# A short expiration - it can always be raised, but it is hard to lower
# We expect promotion within 60d, or for testing to "move on", but
# it is also short enough that people should notice occasionally,
# and not accidentally think of the staging buckets as permanent.
#
# TODO: currently this only applies to GCS, as GCR has no native way
#       of auto-deleting images based on age
readonly AUTO_DELETION_DAYS=60

#
# Global k8s-infra configuration (something else provisioned these)
#

readonly PROD_PROJECT="k8s-artifacts-prod"

PROD_IMAGE_PROMOTER_SCANNING_SERVICE_ACCOUNT="$(svc_acct_email "${PROD_PROJECT}" "${IMAGE_PROMOTER_VULN_SCANNING_SVCACCT}")"
readonly PROD_IMAGE_PROMOTER_SCANNING_SERVICE_ACCOUNT

#
# Staging functions
#

# Provision and configure a "staging" GCP project, intended to hold
# temporary release artifacts in a pre-provisioned GCS bucket or
# GCR. The intent is to then promote some of these artifacts to
# production, which is long-lived and immutable.
#
# Artifacts are ideally written here via automation, either via GCB
# builds run within the project, or by prowjobs running in a trusted
# cluster (currently: k8s-infra-prow-build-trusted)
#
# As a fallback, a per-project group of humans is given access to
# manually write artifacts andtrigger GCB builds in the project
#
# $1: GCP project name (e.g. "k8s-staging-foo")
# $2: Group for manual access (e.g. "k8s-infra-staging-foo@kubernetes.io")
function ensure_staging_project() {
    if [ $# != 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(gcp_project, writers_group) requires 2 arguments" >&2
        return 1
    fi
    local project="${1}"
    local writers="${2}"
    # Enforcing a location for the GCP Artifact Registry
    local location="us-central1"

    # The names of the buckets
    local staging_bucket="gs://${project}" # used by humans
    local gcb_bucket="gs://${project}-gcb" # used by GCB

    local cip_principal="serviceAccount:${PROD_IMAGE_PROMOTER_SCANNING_SERVICE_ACCOUNT}"

    color 6 "Ensuring project exists: ${project}"
    ensure_project "${project}"

    color 6 "Ensuring ${writers} are project viewers"
    ensure_project_role_binding "${project}" "group:${writers}" "roles/viewer"

    # Enable services for staging projects and their direct dependencies; prune anything else
    color 6 "Ensuring necessary enabled services staging project: ${project}"
    # NOTE: horrible bash to allow special cases of staging projects needing
    #       more services than the default set... since bash doesn't let us
    #       pass around arrays, wrap an array in a function that echoes it,
    #       and append the output of that function to the default set
    local special_case_services="staging_special_case_services__${project//-/_}"
    local enabled_services=("${STAGING_PROJECT_SERVICES[@]}")
    if [ "$(type -t "${special_case_services}")" == "function" ]; then
        mapfile -t -O "${#enabled_services[@]}" enabled_services < <(${special_case_services})
    fi
    K8S_INFRA_ENSURE_ONLY_SERVICES_WILL_FORCE_DISABLE=true \
      ensure_only_services "${project}" "${enabled_services[@]}"

    color 6 "Ensuring disabled services for staging project: ${project}"
    ensure_disabled_services "${project}" "${STAGING_PROJECT_DISABLED_SERVICES[@]}"

    # TODO(spiffxp): remove when binding has been removed
    color 6 "Ensuring containeranalysis service agent binding removed for staging project: ${project}"
    ensure_removed_containeranalysis_serviceagent "${project}"

    # Enable image promoter access to vulnerability scanning results
    color 6 "Ensuring ${cip_principal} can view vulnernability scanning results for project: ${project}"
    ensure_project_role_binding "${project}" "${cip_principal}" "roles/containeranalysis.occurrences.viewer"

    # Ensure staging AR repo
    color 3 "Ensuring staging AR repo: ${location}-docker.pkg.dev/${project}/images"
    ensure_ar_repo "${project}" "${location}" 2>&1 | indent

    # Ensure staging project GCR

    color 3 "Ensuring staging GCR repo: gcr.io/${project}"
    ensure_staging_gcr_repo "${project}" "${writers}" 2>&1 | indent

    # Ensure staging project GCS

    color 3 "Ensuring staging GCS bucket: ${staging_bucket}"
    ensure_staging_gcs_bucket "${project}" "${staging_bucket}" "${writers}" "true" 2>&1 | indent

    # Ensure staging project GCB

    color 3 "Ensuring staging GCB"
    ensure_staging_gcb "${project}" "${gcb_bucket}" "${writers}" 2>&1 | indent

    # Ensure any additional special case configuration

    local special_case_func="staging_special_case__${project//-/_}"
    if [ "$(type -t "${special_case_func}")" == "function" ]; then
        color 6 "Ensuring special case configuration for ${project}"
        "${special_case_func}"
    fi
}

# Ensure the given GCS bucket exists in the given staging project
# with auto-deletion enabled and appropriate permissions for the
# given group and GCS admins. If an optional fourth parameter is
# set to "true", access logging will be enabled.
#
# $1: The GCP project (e.g. k8s-staging-foo)
# $2: The GCS bucket (e.g. gs://k8s-staging-foo)
# $3: The group to grant write access (e.g. k8s-infra-staging-foo@kubernetes.io)
# [$4:] Enable access logs (e.g. "true", default: false)
function ensure_staging_gcs_bucket() {
    if [ $# -lt 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "${FUNCNAME[0]}(project, gcs_bucket, writers, [logging]) requires at least 3 arguments" >&2
        return 1
    fi
    local project="${1}"
    local bucket="${2}"
    local writers="${3}"
    local logging="${4:-false}"

    color 6 "Ensuring ${bucket} exists and is world readable in project: ${project}"
    ensure_public_gcs_bucket "${project}" "${bucket}"

    color 6 "Ensuring ${bucket} has auto-deletion of ${AUTO_DELETION_DAYS} days"
    ensure_gcs_bucket_auto_deletion "${bucket}" "${AUTO_DELETION_DAYS}"

    color 6 "Ensuring GCS admins can admin ${bucket} in project: ${project}"
    empower_gcs_admins "${project}" "${bucket}"

    color 6 "Ensuring ${writers} can write to ${bucket} in project: ${project}"
    empower_group_to_write_gcs_bucket "${writers}" "${bucket}"

    if [ "${logging}" == "true" ]; then
      color 6 "Ensuring GCS access logs enabled for ${bucket} in project: ${project}"
      ensure_gcs_bucket_logging "${bucket}"
    fi
}

# Ensure a GCR repo is provisioned in the given staging project, with
# appropriate permissions for the given group and GCR admins
# with auto-deletion enabled and appropriate permissions for the
# given group and GCS admins
#
# $1: The GCP project (e.g. k8s-staging-foo)
# $2: The group to grant write access (e.g. k8s-infra-staging-foo@kubernetes.io)
function ensure_staging_gcr_repo() {
    if [ $# != 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(project, writers) requires 2 arguments" >&2
        return 1
    fi
    local project="${1}"
    local writers="${2}"
    local gcr_bucket="gs://artifacts.${1}.appspot.com"

    color 6 "Ensuring a GCR repo exists for project: ${project}"
    ensure_gcr_repo "${project}"

    color 6 "Ensuring ${writers} can write to GCR for project: ${project}"
    empower_group_to_write_gcr "${writers}" "${project}"

    color 6 "Ensuring GCR admins can admin GCR for project: ${project}"
    empower_gcr_admins "${project}"

    color 6 "Ensuring GCS access logs enabled for GCR bucket in project: ${project}"
    ensure_gcs_bucket_logging "${gcr_bucket}"
}

# Ensure GCB is setup for the given staging project, by ensuring the
# given staging GCS bucket exists, and allowing the given group and a
# prow service account to write to the GCS bucket and trigger GCB
#
# $1: The GCP project (e.g. k8s-staging-foo)
# $2: The GCS bucket (e.g. gs://k8s-staging-foo)
# $3: The group to grant write access (e.g. k8s-infra-staging-foo@kubernetes.io)
function ensure_staging_gcb() {
  if [ $# != 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "${FUNCNAME[0]}(project, gcs_bucket, writers) requires 3 arguments" >&2
        return 1
    fi
    local project="${1}"
    local bucket="${2}"
    local writers="${3}"

    # TODO: this should use ensure_staging_gcb_builder_service_account and
    #       grant access to that instead; once image-builder jobs have been
    #       moved over, remove support for this service account
    local serviceaccount="${GCB_BUILDER_SVCACCT}"
    local principal="serviceAccount:${serviceaccount}"

    color 6 "Ensuring staging bucket: ${bucket}"
    ensure_staging_gcs_bucket "${project}" "${bucket}" "${writers}" 2>&1 | indent

    color 6 "Ensuring ${writers} can use GCB in project: ${project}"
    empower_group_for_gcb "${project}" "${writers}"

    color 6 "Ensuring ${serviceaccount} can use GCB in project: ${project}"
    ensure_project_role_binding "${project}" "${principal}" "roles/cloudbuild.builds.builder"
    ensure_gcs_role_binding "${bucket}" "${principal}" "objectCreator"
    ensure_gcs_role_binding "${bucket}" "${principal}" "objectViewer"

    local sa_name="gcb-image-builder"
    local sa_email="${sa_name}@${project}.iam.gserviceaccount.com"
    local sa_principal="serviceAccount:${sa_email}"
    color 6 "Ensuring ${sa_email} exists and can sign artifacts in project: ${project}"
    ensure_service_account \
      "${project}" \
      "${sa_name}" \
      "used by prow to build container images and sign artifacts for ${project}"

    ensure_serviceaccount_role_binding \
        "${sa_email}" \
        "${sa_principal}" \
        "roles/iam.serviceAccountTokenCreator"

    ensure_project_role_binding \
        "${project}" \
        "${sa_principal}" \
        "roles/cloudbuild.builds.editor"
}

# TODO(spiffxp): rename this to just prow@project and deprecate/rm the gcb-builder-foo
#                serviceaccounts; this will allow prowjobs to write to GCS or GCR in
#                the project directly, as well as triggering GCB to do the same
# Create a gcb-builder-{staging} GCP service account in project k8s-staging-{staging}
# that can trigger GCB within that project. Allow GKE clusters in {prow_project}
# to use this when running pods as a kubernetes service account of the same name in
# PROWJOB_POD_NAMESPACE
#
# $1: The staging name (e.g. kubetest2)
# $2: The prow project name (e.g. k8s-infra-prow-build)
function ensure_staging_gcb_builder_service_account() {
    if [ $# != 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(staging, prow_project) requires 2 arguments" >&2
        return 1
    fi

    local staging="$1"
    local prow_project="$2"
    local project="k8s-staging-${staging}"
    local sa_name="gcb-builder-${staging}"
    local sa_email="${sa_name}@${project}.iam.gserviceaccount.com"
    # TODO(spiffxp): pass these in?
    local staging_bucket="gs://${project}"
    local gcb_bucket="gs://${project}-gcb"

    color 6 "Ensuring ${sa_email} exists and can use GCB, GCS, GCR in project: ${project}"
    ensure_service_account \
      "${project}" \
      "${sa_name}" \
      "used by prow to use GCB, write to GCR and GCS for ${project}"

    empower_svcacct_to_write_gcr "${sa_email}" "${project}"

    local principal="serviceAccount:${sa_email}"
    ensure_project_role_binding "${project}" "${principal}" "roles/cloudbuild.builds.builder"
    ensure_gcs_role_binding "${staging_bucket}" "${principal}" "objectCreator"
    ensure_gcs_role_binding "${staging_bucket}" "${principal}" "objectViewer"
    ensure_gcs_role_binding "${gcb_bucket}" "${principal}" "objectCreator"
    ensure_gcs_role_binding "${gcb_bucket}" "${principal}" "objectViewer"

    color 6 "Ensuring GKE clusters in '${prow_project}' can run pods in '${PROWJOB_POD_NAMESPACE}' as '${sa_email}'"
    empower_gke_for_serviceaccount \
        "${prow_project}" \
        "${PROWJOB_POD_NAMESPACE}" \
        "${sa_email}"
}

# Ensures the containeranalysis service agent iam binding has been removed
# from the given project (as well as any other members that happen to have
# the service agent role)
#
# $1: The project name
function ensure_removed_containeranalysis_serviceagent() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local role="roles/containeranalysis.ServiceAgent"

    gcloud projects get-iam-policy "${project}" > "${TMPDIR}/iam.yaml"
    mapfile -t members < <(
      <"${TMPDIR}/iam.yaml" yq -r ".bindings | map(select(.role==\"${role}\").members) | flatten | .[]"
    )
    for member in "${members[@]}"; do
      ensure_removed_project_role_binding "${project}" "${member}" "${role}"
    done
}

#
# Special cases
#

# Release Manager special cases
function ensure_release_manager_special_cases() {
    for project in "${RELEASE_STAGING_PROJECTS[@]}"; do
        # Release Manager Associates need view access to Release Engineering
        # projects
        color 6 "Empowering ${RELEASE_VIEWERS} as project viewers in ${project}"
        ensure_project_role_binding "${project}" "group:${RELEASE_VIEWERS}" "roles/viewer"

        # For k8s-staging-kubernetes, grant the kubernetes-release-test (old
        # staging) GCB service account admin GCR access to the new staging
        # project for Kubernetes releases. This is required for VDF as we need
        # to continue running stages/releases from the old project while
        # publishing container images to new project.
        # ref: https://github.com/kubernetes/release/pull/1230
        if [[ "${project}" == "k8s-staging-kubernetes" ]]; then
            color 6 "Empowering kubernetes-release-test GCB service account to admin GCR"
            empower_svcacct_to_admin_gcr "648026197307@cloudbuild.gserviceaccount.com" "${project}"
        fi

        # For k8s-staging-releng,
        # - create a GCS bucket for system packages
        # - ensure k8s-release-editors@kubernetes can write objects to the bucket
        # This is required to investage migration from Google infrastucture to
        # the community-owned infrastructure. See: https://github.com/kubernetes/release/issues/913
        if [[ "${project}" == "k8s-staging-experimental" ]]; then
            ensure_private_gcs_bucket "${project}" "gs://k8s-artifacts-system-packages-sandbox"
            ensure_gcs_role_binding "gs://k8s-artifacts-system-packages-sandbox" \
                "group:k8s-infra-release-editors@kubernetes.io" \
                "objectAdmin"
        fi

        # Artifact Registry
        #
        # Enable Google Artifact Registry to allow Release Managers to prepare
        # for GCR to Artifact Registry migration
        # ref: https://github.com/kubernetes/k8s.io/issues/1343
        ensure_services "${project}" artifactregistry.googleapis.com

        # Roles: https://cloud.google.com/artifact-registry/docs/access-control#roles
        #
        # Empower Release Manager admins to create and manage repositories and
        # artifacts
        ensure_project_role_binding "${project}" "group:${RELEASE_ADMINS}" "roles/artifactregistry.admin"

        # Empower Release Managers to read, write, and delete artifacts
        ensure_project_role_binding "${project}" "group:${RELEASE_MANAGERS}" "roles/artifactregistry.repoAdmin"
    done 2>&1 | indent
}

# In order for ci-kubernetes-build to run on k8s-infra-prow-build,
# it needs write access to gcr.io/k8s-staging-ci-images. For now,
# we will grant the prow-build service account write access. Longer
# term we would prefer service accounts per project, and restrictions
# on which jobs can use which service accounts.
function staging_special_case__k8s_staging_ci_images() {
    empower_svcacct_to_write_gcr "${PROW_BUILD_SERVICE_ACCOUNT}" "k8s-staging-ci-images"
}

# In order to build the node images using image-builder it needs
# the compute api to be enabled because it will create a VM
# to build the node image.
function staging_special_case_services__k8s_staging_cluster_api_gcp() {
    # needed to build images using packer via image-builder
    echo compute.googleapis.com
    # dependency of compute
    echo oslogin.googleapis.com
}
function staging_special_case__k8s_staging_cluster_api_gcp() {
    readonly suffix="cluster-api-gcp"
    readonly project="k8s-staging-${suffix}"
    local serviceaccount
    serviceaccount="$(svc_acct_email "${project}" "gcb-builder-cluster-api-gcp")"

    ensure_project_role_binding "${project}" "serviceAccount:${serviceaccount}" "roles/compute.instanceAdmin.v1"
    ensure_serviceaccount_role_binding "${serviceaccount}" "serviceAccount:${serviceaccount}" "roles/iam.serviceAccountUser"
    ensure_staging_gcb_builder_service_account "${suffix}" "k8s-infra-prow-build-trusted"
}


# In order to build the release artifacts, the group needs to be
# able to create and manage a keyring to encrypt a secret token
# that will be accessed and decrypted by a cloud build job.
function staging_special_case__k8s_staging_kustomize() {
    readonly project="k8s-staging-kustomize"
    local principal

    # ensure owners can manage keyrings
    local owners="k8s-infra-staging-kustomize@kubernetes.io"
    principal="group:${owners}"
    ensure_project_role_binding "${project}" "${principal}" "roles/cloudkms.admin"
    ensure_project_role_binding "${project}" "${principal}" "roles/cloudkms.cryptoKeyEncrypter"

    # ensure cloud builds can access keyrings for decryption
    local cloudbuild_sa_email="660796270509@cloudbuild.gserviceaccount.com"
    principal="serviceAccount:${cloudbuild_sa_email}"
    ensure_project_role_binding "${project}" "${principal}" "roles/cloudkms.cryptoKeyDecrypter"
    ensure_project_role_binding "${project}" "${principal}" "roles/secretmanager.secretAccessor"
}

# In order to build the release artifacts, the group needs to be
# able to create and manage a keyring to encrypt a secret token
# that will be accessed and decrypted by a cloud build job.
function staging_special_case__k8s_staging_krm_functions() {
    readonly project="k8s-staging-krm-functions"
    local principal

    # ensure owners can manage keyrings
    local owners="k8s-infra-staging-krm-functions@kubernetes.io"
    principal="group:${owners}"
    ensure_project_role_binding "${project}" "${principal}" "roles/cloudkms.admin"
    ensure_project_role_binding "${project}" "${principal}" "roles/cloudkms.cryptoKeyEncrypter"

    # ensure cloud builds can access keyrings for decryption
    local cloudbuild_sa_email="415435679132@cloudbuild.gserviceaccount.com"
    principal="serviceAccount:${cloudbuild_sa_email}"
    ensure_project_role_binding "${project}" "${principal}" "roles/cloudkms.cryptoKeyDecrypter"
    ensure_project_role_binding "${project}" "${principal}" "roles/secretmanager.secretAccessor"
}

# In order for pull-release-image-* to run on k8s-infra-prow-build,
# it needs write access to gcr.io/k8s-staging-releng-test. We are
# wary of what untrusted code is allowed to do, so we don't allow
# presubmits to run on k8s-infra-prow-build-trusted.
function staging_special_case__k8s_staging_releng_test() {
    ensure_staging_gcb_builder_service_account "releng-test" "k8s-infra-prow-build"

    # Ensure CloudBuild jobs can access keyrings on GCP project k8s-releng-prod for decryption
    local cloudbuild_sa_email="86929635859@cloudbuild.gserviceaccount.com"
    principal="serviceAccount:${cloudbuild_sa_email}"

    readonly project="k8s-releng-prod"
    ensure_project_role_binding "${project}" "${principal}" "roles/cloudkms.cryptoKeyDecrypter"
    ensure_project_role_binding "${project}" "${principal}" "roles/secretmanager.secretAccessor"
}

# sig-storage has these enabled
function staging_special_case_services__k8s_staging_sig_storage() {
    echo compute.googleapis.com
    # dependency of compute
    echo oslogin.googleapis.com
}

#
# main
#

function ensure_staging_projects() {
    color 6 "Ensuring staging projects..."

    # default to all staging projects
    if [ $# = 0 ]; then
        set -- "${STAGING_PROJECTS[@]}"
    fi

    for arg in "${@}"; do
        local repo="${arg#k8s-staging-}"
        local project="k8s-staging-${repo}"
        if ! k8s_infra_project "staging" "${project}" >/dev/null; then
            color 1 "Skipping unrecognized staging project name: ${project}"
            continue
        fi

        color 3 "Configuring staging project: ${project}"
        ensure_staging_project \
            "${project}" \
            "k8s-infra-staging-${repo}@kubernetes.io" \
            2>&1 | indent

    done

    color 6 "Configuring special cases for Release Managers"
    ensure_release_manager_special_cases

    color 6 "Done"
}

ensure_staging_projects "${@}"
