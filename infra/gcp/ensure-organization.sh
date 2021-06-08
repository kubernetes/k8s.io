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

# This script creates & configures the project that governs access to GSuite
# APIs.

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

org_roles=(
    prow.viewer
    audit.viewer
    secretmanager.secretLister
    organization.admin
    CustomRole
    iam.serviceAccountLister
    container.deployer
)

removed_org_roles=()

org_role_bindings=(
  # empower k8s-infra-org-admins@
  # NOTE: roles/owner has too many permissions to aggregate into a custom role,
  # and some services automatically add bindings for roles/owner, e.g.
  # https://cloud.google.com/storage/docs/access-control/iam-roles#basic-roles-intrinsic
  "group:k8s-infra-gcp-org-admins@kubernetes.io:roles/owner"
  "group:k8s-infra-gcp-org-admins@kubernetes.io:$(custom_org_role_name "organization.admin")"
  # orgpolicy.policy.set is not allowed in custom roles, this is the only role that has it
  "group:k8s-infra-gcp-org-admins@kubernetes.io:roles/orgpolicy.policyAdmin"
  

  # empower k8s-infra-prow-oncall@ to use GCP Console to navigate to their projects
  "group:k8s-infra-prow-oncall@kubernetes.io:roles/browser"

  # TODO: not sure this is required for GKE Google Group RBAC, is this proxy
  #       for "let people running apps in aaa use GCP console to navigate" ?
  "group:gke-security-groups@kubernetes.io:roles/browser"

  # TODO: what is the purpose of this role?
  "group:k8s-infra-gcp-accounting@kubernetes.io:$(custom_org_role_name "CustomRole")"

  # empower k8s-infra-gcp-auditors@ and equivalent service-account
  "group:k8s-infra-gcp-auditors@kubernetes.io:$(custom_org_role_name "audit.viewer")"
  "serviceAccount:$(svc_acct_email "kubernetes-public" "k8s-infra-gcp-auditor"):$(custom_org_role_name "audit.viewer")"
)

removed_org_role_bindings=()

function ensure_org_roles() {
    for role in "${org_roles[@]}"; do
        color 6 "Ensuring organization custom role ${role}"
        ensure_custom_org_iam_role_from_file "${role}" "${SCRIPT_DIR}/roles/${role}.yaml"
    done
}

function ensure_removed_org_roles() {
    for role in "${removed_org_roles[@]}"; do
        color 6 "Ensuring removed organization custom role ${role}"
        ensure_removed_custom_org_iam_role "${role}"
    done
}

function ensure_org_role_bindings() {
    for binding in "${org_role_bindings[@]}"; do
        principal_type="$(echo "${binding}" | cut -d: -f1)"
        principal_email="$(echo "${binding}" | cut -d: -f2)"
        principal="$(echo "${binding}" | cut -d: -f1-2)"
        role="$(echo "${binding}" | cut -d: -f3-)"

        # avoid dependency-cycles by skipping, e.g.
        # - serviceaccount bound in this script, created by ensure-main-project.sh
        # - custom org roles used by ensure-main-project.sh, created by this script
        # - so allow this to run to completion before ensure-main-project.sh, and
        #   accept that bootstrapping means: run this, then that, then this again
        case ${principal_type} in
        serviceAccount)
            if ! gcloud iam service-accounts describe "${principal_email}" >/dev/null 2>&1; then
                color 2 "Skipping ${principal} bound to ${role}: principal does not exist"
                continue
            fi
            ;;
        group|user) ;; # TODO: need access to Directory API
        esac

        color 6 "Ensuring ${principal} bound to ${role}"
        ensure_org_role_binding "${principal}" "${role}" 2>&1 | indent
    done
}

function ensure_removed_org_role_bindings() {
    for binding in "${removed_org_role_bindings[@]}"; do
        principal="$(echo "${binding}" | cut -d: -f1-2)"
        role="$(echo "${binding}" | cut -d: -f3-)"
        color 6 "Ensuring ${principal} bound to ${role}"
        ensure_removed_org_role_binding "${principal}" "${role}" 2>&1 | indent
    done
}

function main() {
    color 6 "Ensuring organization custom roles exist"
    ensure_org_roles 2>&1 | indent

    color 6 "Ensuring organization IAM bindings exist"
    ensure_org_role_bindings 2>&1 | indent

    color 6 "Ensuring removed organization IAM bindings do not exist"
    ensure_removed_org_role_bindings 2>&1 | indent

    color 6 "Ensuring removed organization custom roles do not exist"
    ensure_removed_org_roles 2>&1 | indent

    color 6 "All done!"
}

main
