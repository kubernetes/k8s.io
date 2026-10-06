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

# This script is used to ensure Release Engineering subproject owners have the
# appropriate access to SIG Release prod GCP projects.
#
# Projects:
# - k8s-releng-prod - Stores KMS objects which other release projects will
#                       be granted permission to decrypt e.g., GITHUB_TOKEN

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 [project...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all release projects" > /dev/stderr
    echo "  $0 k8s-releng-prod # just do one" > /dev/stderr
    echo > /dev/stderr
}

mapfile -t PROJECTS < <(k8s_infra_projects "releng")
readonly PROJECTS

if [ $# = 0 ]; then
    # default to all release projects
    set -- "${PROJECTS[@]}"
fi

RELEASE_PROCESS_CLOUDBUILD_SVCACCT="648026197307@cloudbuild.gserviceaccount.com"
STAGING_SIGNER_SVCACCT="krel-staging"
K8s_ORG_SIGNER_SVCACCT="krel-trust"
SUMMARY_SIGNER_SVCACCT="promoter-summaries"
PROMOTER_PROJECT="k8s-artifacts-prod"

# This function ensures the cross-project impersonation
# constraint is not enforced in the project. This is required
# to allow principals from other projects to impersonate
# service accounts from k8s-releng-prod 
function ensure_cross_project_constraint() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "ensure_cross_project_constraint requires a project name" >&2
        return 1
    fi
    local project="${1}"

    # Read the project number
    local project_id
    project_id=$(gcloud projects describe "${project}" --format='value(projectNumber)')
    
    # Check if the constraint is enabled
    local status_file
    status_file=$(mktemp)
    if gcloud --project="${project}" org-policies describe \
        iam.disableCrossProjectServiceAccountUsage > /dev/null 2>"${status_file}"; then
        return
    fi

    # If checking the contraint was not successful, check the error
    if ! (grep "NOT_FOUND:" "${status_file}"); then
        echo "Error checking cross-project contraint status" >&2
        return 1
    fi

    # Its enforced, disable it with a policy
    echo " >> disabling cross-project impersonation enforcement"
    local policy_file
    policy_file=$(mktemp)
    {
        echo "name: projects/${project_id}/policies/iam.disableCrossProjectServiceAccountUsage"
        echo "spec:"
        echo "  rules:"
        echo "  - enforce: false" 
    } > "${policy_file}"
    gcloud org-policies set-policy "${policy_file}" --project "${project}" || return 1
}

# Ensure the signer service accounts exist and the
# required accounts have access to them as token creators
function ensure_signer_service_accounts() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "ensure_signer_service_accounts requires a project name" >&2
        return 1
    fi
    
    local project="${1}"

    # Service account for signing artifacts during staging
    color 6 "Ensuring staging signing account"
    ensure_service_account \
        "${project}" \
        "${STAGING_SIGNER_SVCACCT}" \
        "krel staging signing account"

    # Service account for signing artifacts during staging
    color 6 "Ensuring main Kubernetes org signing account"
    ensure_service_account \
        "${project}" \
        "${K8s_ORG_SIGNER_SVCACCT}" \
        "Kubernetes signer account"
        
    # The cloud build account needs to be able to produce OIDC identity
    # tokens with the staging signer identity
    staging_sign_account="$(svc_acct_email "${project}" "${STAGING_SIGNER_SVCACCT}")"
    ensure_serviceaccount_role_binding \
        "${staging_sign_account}" \
        "serviceAccount:${RELEASE_PROCESS_CLOUDBUILD_SVCACCT}" \
        "roles/iam.serviceAccountTokenCreator"

    # Only the production image promotion jobs and the signature check sign
    # with the main Kubernetes signing account, see below. File promotion
    # doesn't sign, and the former image promoter account is left with the
    # ar-to-s3-sync job, which only copies, since the promotion jobs moved to
    # their own account and the promo-tools canary jobs were removed.
    prod_sign_account="$(svc_acct_email "${project}" "${K8s_ORG_SIGNER_SVCACCT}")"
    promoter_file_account="$(svc_acct_email "${PROMOTER_PROJECT}" "${FILE_PROMOTER_SVCACCT}")"
    promoter_image_account="$(svc_acct_email "${PROMOTER_PROJECT}" "${IMAGE_PROMOTER_SVCACCT}")"

    ensure_removed_serviceaccount_role_binding \
        "${prod_sign_account}" \
        "serviceAccount:${promoter_file_account}" \
        "roles/iam.serviceAccountTokenCreator"

    ensure_removed_serviceaccount_role_binding \
        "${prod_sign_account}" \
        "serviceAccount:${promoter_image_account}" \
        "roles/iam.serviceAccountTokenCreator"

    color 6 "Ensuring image promoter verification summary signing account"
    ensure_service_account \
        "${project}" \
        "${SUMMARY_SIGNER_SVCACCT}" \
        "Kubernetes image promoter verification summary signer"

    # The production image promotion jobs sign the images they promote with
    # the main Kubernetes signing account, and the verification summaries
    # with their own account, which only they can use. Consumers pin it as
    # the verifier of the promoted images. The account of the jobs is created
    # by the Terraform of k8s-artifacts-prod in kubernetes/k8s.io#8817, which
    # was applied before it merged, so it has to exist first.
    promotion_jobs_account="$(svc_acct_email "${PROMOTER_PROJECT}" "${PROD_IMAGE_PROMOTION_SVCACCT}")"

    ensure_serviceaccount_role_binding \
        "${prod_sign_account}" \
        "serviceAccount:${promotion_jobs_account}" \
        "roles/iam.serviceAccountTokenCreator"

    ensure_serviceaccount_role_binding \
        "$(svc_acct_email "${project}" "${SUMMARY_SIGNER_SVCACCT}")" \
        "serviceAccount:${promotion_jobs_account}" \
        "roles/iam.serviceAccountTokenCreator"
}

for PROJECT; do

    if ! k8s_infra_project "releng" "${PROJECT}" >/dev/null; then
        color 1 "Skipping unrecognized release project name: ${PROJECT}"
        continue
    fi

    color 3 "Configuring: ${PROJECT}"

    # Make the project, if needed
    color 6 "Ensuring project exists: ${PROJECT}"
    ensure_project "${PROJECT}"

    # Enable admins to use the UI
    color 6 "Empowering ${RELEASE_ADMINS} as project viewers"
    empower_group_as_viewer "${PROJECT}" "${RELEASE_ADMINS}"

    # Enable KMS and IAM APIs
    color 6 "Enabling the KMS and IAM Credentials APIs"
    ensure_only_services "${PROJECT}" cloudkms.googleapis.com iamcredentials.googleapis.com orgpolicy.googleapis.com

    # Let project admins use KMS.
    color 6 "Empowering ${RELEASE_ADMINS} as KMS admins"
    empower_group_for_kms "${PROJECT}" "${RELEASE_ADMINS}"

    # Ensure service accounts and role bindings.
    ensure_signer_service_accounts "${PROJECT}"

    # The default compute service account gets the editor role, which
    # includes acting as the signing accounts, but nothing runs as it.
    color 6 "Ensuring the default compute service account has no editor role"
    compute_account="$(gcloud projects describe "${PROJECT}" --format='value(projectNumber)')-compute@developer.gserviceaccount.com"
    ensure_removed_project_role_binding \
        "${PROJECT}" \
        "serviceAccount:${compute_account}" \
        "roles/editor"

    # Ensure project allows impersonation access form other accounts
    color 6 echo "Ensuring cross-project impersonation constraint is not enforced"
    ensure_cross_project_constraint "${PROJECT}"

    color 6 "Done"
done
