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
)

old_org_roles=(
    StorageBucketLister
)

# TODO(https://github.com/kubernetes/k8s.io/issues/1659): obviated by organization.admin, remove when bindings gone
old_org_admin_roles=(
    roles/billing.user
    roles/iam.organizationRoleAdmin
    roles/resourcemanager.organizationAdmin
    roles/resourcemanager.projectCreator
    roles/resourcemanager.projectDeleter
    roles/servicemanagement.quotaAdmin
)

color 6 "Ensuring organization custom roles exist"
(
    for role in "${org_roles[@]}"; do
      color 6 "Ensuring organization custom role ${role}"
      ensure_custom_org_iam_role_from_file "${role}" "${SCRIPT_DIR}/roles/${role}.yaml"
    done
) 2>&1 | indent

color 6 "Ensuring organization IAM bindings exist"
(
    # k8s-infra-prow-oncall@kubernetes.io should be able to browse org resources
    ensure_org_role_binding "group:k8s-infra-prow-oncall@kubernetes.io" "roles/browser"
    
    # TODO: this already exists, but seems overprivileged for a group that is about
    #       access to the "aaa" cluster in "kubernetes-public"
    ensure_org_role_binding "group:gke-security-groups@kubernetes.io" "roles/browser"

    # k8s-infra-gcp-accounting@
    ensure_org_role_binding "group:k8s-infra-gcp-accounting@kubernetes.io" "$(custom_org_role_name "CustomRole")"

    # k8s-infra-gcp-auditors@
    ensure_org_role_binding "group:k8s-infra-gcp-auditors@kubernetes.io" "$(custom_org_role_name "audit.viewer")"

    # k8s-infra-org-admins@
    # roles/owner has too many permissions to aggregate into a custom role,
    # and some services (e.g. storage) add bindings based on membership in it
    ensure_org_role_binding "group:k8s-infra-gcp-org-admins@kubernetes.io" "roles/owner"
    # everything org admins need beyond roles/owner to manage the org
    ensure_org_role_binding "group:k8s-infra-gcp-org-admins@kubernetes.io" "$(custom_org_role_name "organization.admin")"
) 2>&1 | indent

color 6 "Ensuring removed organization IAM bindings do not exist"
(
    for role in "${old_org_admin_roles[@]}"; do
        # TODO(spiffxp): remove the extra super duper paranoia once we verify
        #                I haven't locked myself out via group membership
        ensure_org_role_binding "user:thockin@google.com" "${role}"
        ensure_org_role_binding "user:davanum@gmail.com" "${role}"
    done
) 2>&1 | indent

color 6 "Ensuring removed organization custom roles do not exist"
(
    for role in "${old_org_roles[@]}"; do
      color 6 "Ensuring removed organization custom role ${role}"
      ensure_removed_custom_org_iam_role "${role}"
    done
) 2>&1 | indent

color 6 "All done!"
