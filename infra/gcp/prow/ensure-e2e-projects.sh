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

# This script creates & configures projects intended to be used for e2e
# testing of kubernetes and managed by boskos

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/../lib.sh"

function usage() {
    echo "usage: $0 [repo...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all projects" > /dev/stderr
    echo "  $0 k8s-infra-node-e2e-project # just do one" > /dev/stderr
    echo > /dev/stderr
}

## projects hosting prow build clusters managed by wg-k8s-infra

BUILD_CLUSTER_PROJECT=$(k8s_infra_project "prow" "k8s-infra-prow-build")
TRUSTED_BUILD_CLUSTER_PROJECT=$(k8s_infra_project "prow" "k8s-infra-prow-build-trusted")

## setup service accounts and ips for the prow build cluster

PROW_BUILD_SVCACCT=$(svc_acct_email "${BUILD_CLUSTER_PROJECT}" "prow-build")
BOSKOS_JANITOR_SVCACCT=$(svc_acct_email "${BUILD_CLUSTER_PROJECT}" "boskos-janitor")

## setup projects to be used by e2e tests for standing up clusters

mapfile -t E2E_PROJECTS < <(k8s_infra_projects "e2e")
readonly E2E_PROJECTS

function ensure_e2e_project() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project) requires 1 argument" >&2
        return 1
    fi
    local prj="${1}"

    ensure_project "${prj}"

    color 6 "Ensure stale role bindings have been removed from e2e project: ${prj}"
    (
        echo "no stale bindings slated for removal"
    ) 2>&1 | indent

    color 6 "Ensuring only APIs necessary for kubernetes e2e jobs to use e2e project: ${prj}"
    ensure_only_services "${prj}" \
        compute.googleapis.com \
        containerregistry.googleapis.com \
        logging.googleapis.com \
        monitoring.googleapis.com \
        storage-component.googleapis.com

    # TODO: this is what prow.k8s.io uses today, but seems overprivileged, we
    #       could consider using a more limited custom IAM role instead
    color 6 "Empower prow-build service account to edit e2e project: ${prj}"
    ensure_project_role_binding "${prj}" \
      "serviceAccount:${PROW_BUILD_SVCACCT}" \
      "roles/editor"

    # TODO: this is what prow.k8s.io uses today, but seems overprivileged, we
    #       could consider using a more limited custom IAM role instead
    color 6 "Empower boskos-janitor service account to clean e2e project: ${prj}"
    ensure_project_role_binding "${prj}" \
      "serviceAccount:${BOSKOS_JANITOR_SVCACCT}" \
      "roles/editor"

    color 6 "Empower k8s-infra-prow-oncall@kubernetes.io to admin e2e project: ${prj}"
    ensure_project_role_binding "${prj}" \
      "group:k8s-infra-prow-oncall@kubernetes.io" \
      "roles/owner"

    # NB: prow.viewer role is defined in ensure-organization.sh, that needs to have been run first
    color 6 "Empower k8s-infra-prow-viewers@kubernetes.io to view specific resources in e2e project: ${prj}"
    ensure_project_role_binding "${prj}" \
      "group:k8s-infra-prow-viewers@kubernetes.io" \
      "$(custom_org_role_name "prow.viewer")"

    if [[ "${prj}" =~ k8s-infra-e2e.*scale ]]; then
      color 6 "Empower k8s-infra-sig-scalability-oncall@kubernetes.io to admin e2e project: ${prj}"
      ensure_project_role_binding "${prj}" \
        "group:k8s-infra-sig-scalability-oncall@kubernetes.io" \
        "roles/owner"
    fi

    color 6 "Ensure prow-build prowjobs are able to ssh to instances in e2e project: ${prj}"
    prow_build_ssh_pubkey="prow:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCmYxHh/wwcV0P1aChuFLpl28w6DFyc7G5Xrw1F8wH1Re9AdxyemM2bTZ/PhsP3u9VDnNbyOw3UN00VFdumkFLjLf1WQ7Q6rZDlPjlw7urBIvAMqUecY6ae1znqsZ0dMBxOuPXHznlnjLjM5b7O7q5WsQMCA9Szbmz6DsuSyCuX0It2osBTN+8P/Fa6BNh3W8AF60M7L8/aUzLfbXVS2LIQKAHHD8CWqvXhLPuTJ03iSwFvgtAK1/J2XJwUP+OzAFrxj6A9LW5ZZgk3R3kRKr0xT/L7hga41rB1qy8Uz+Xr/PTVMNGW+nmU4bPgFchCK0JBK7B12ZcdVVFUEdpaAiKZ prow"
    ssh_keys_expected=(
      "${prow_build_ssh_pubkey}"
      # TODO(amwat,spiffxp): something is adding an extra prow: prefix, it is
      # unclear where in prow->kubetest2->cluster/log-dump.sh->`gcloud ssh`
      # this is happening
      "prow:${prow_build_ssh_pubkey}"
    )

    # append to project-wide ssh-keys metadata if not present
    ssh_keys_before="${TMPDIR}/ssh-keys.before.txt"
    ssh_keys_after="${TMPDIR}/ssh-keys.after.txt"
    gcloud compute project-info describe --project="${prj}" \
      --format='value(commonInstanceMetadata.items.filter(key:ssh-keys).extract(value).flatten())' \
      | sed -e '/^$/d' > "${ssh_keys_before}"

    cp "${ssh_keys_before}" "${ssh_keys_after}"

    if [ "${K8S_INFRA_ENSURE_E2E_PROJECTS_RESETS_SSH_KEYS:-"false"}" == "true" ]; then
      printf '%s\n' "${ssh_keys_expected[@]}" > "${ssh_keys_after}"
    else
      for ssh_key in "${ssh_keys_expected[@]}"; do
        if ! grep -q "${ssh_key}" "${ssh_keys_before}"; then
          echo "${ssh_key}" >> "${ssh_keys_after}"
        fi
      done
    fi

    if ! diff "${ssh_keys_before}" "${ssh_keys_after}" >/dev/null; then
      gcloud compute project-info add-metadata --project="${prj}" \
        --metadata-from-file ssh-keys="${ssh_keys_after}"
      diff_colorized "${ssh_keys_before}" "${ssh_keys_after}"
    fi
}

# TODO: this should be moved to the terraform responsible for k8s-infra-prow-build-trusted
function ensure_trusted_prow_build_cluster_secrets() {
    local project="${TRUSTED_BUILD_CLUSTER_PROJECT}"
    local secret_specs=(
        k8s-triage-robot-github-token/sig-contributor-experience/github@kubernetes.io
        cncf-ci-github-token/sig-testing/k8s-infra-ii-coop@kubernetes.io
        snyk-token/sig-architecture/k8s-infra-code-organization@kubernetes.io
    )

    for spec in "${secret_specs[@]}"; do
        local secret k8s_group admin_group
        secret="$(echo "${spec}" | cut -d/ -f1)"
        k8s_group="$(echo "${spec}" | cut -d/ -f2)"
        admin_group="$(echo "${spec}" | cut -d/ -f3)"

        local admins=("k8s-infra-prow-oncall@kubernetes.io" "${admin_group}")
        local labels=("group=${k8s_group}")

        color 6 "Ensuring secret '${secret}' exists in '${project}' and is owned by '${admin_group}'"
        ensure_secret "${project}" "${secret}"
        ensure_secret_labels "${project}" "${secret}" "${labels[@]}"
        for group in "${admins[@]}"; do
            ensure_secret_role_binding \
                "$(secret_full_name "${project}" "${secret}")" \
                "group:${group}" \
                "roles/secretmanager.admin"
        done
    done
}

# Enable OS Login at the project level
# $1 The GCP Project
function ensure_project_oslogin() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project) requires 1 argument" >&2
        return 1
    fi

    local prj="${1}"

    enabled=$(gcloud compute project-info describe --project="${prj}" \
      --format='value(commonInstanceMetadata.items[enable-oslogin])')
    if [ "${enabled}" != "TRUE" ]; then
      gcloud compute project-info --project="${prj}" add-metadata --metadata enable-oslogin=TRUE
    fi
}

function disable_project_oslogin() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project) requires 1 argument" >&2
        return 1
    fi

    local prj="${1}"

    enabled=$(gcloud compute project-info describe --project="${prj}" \
      --format='value(commonInstanceMetadata.items[enable-oslogin])')
    if [ "${enabled}" == "TRUE" ]; then
      gcloud compute project-info --project="${prj}" remove-metadata --keys "enable-oslogin"
    fi
}

function ensure_e2e_projects() {
    # default to all staging projects
    if [ $# = 0 ]; then
        set -- "${E2E_PROJECTS[@]}"
    fi

    for project in "${@}"; do
        if ! (printf '%s\n' "${E2E_PROJECTS[@]}" | grep -q "^${project}$"); then
          color 2 "Skipping unrecognized e2e project name: ${project}"
          continue
        fi

        color 3 "Configuring e2e project: ${project}"
        ensure_e2e_project "${project}" 2>&1 | indent

        color 3 "Ensuring OS Login is disabled for $project"
        disable_project_oslogin "${project}" 2>&1 | indent
    done
}

#
# main
#

function main() {
  color 6 "Ensuring external secrets exist for use by k8s-infra-prow-build-trusted"
  ensure_trusted_prow_build_cluster_secrets 2>&1 | indent

  color 6 "Ensuring e2e projects used by prow..."
  ensure_e2e_projects "${@}" 2>&1 | indent

  color 6 "Done"
}

main "${@}"
