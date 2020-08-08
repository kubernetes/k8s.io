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

# This script creates & configures projects intended to be used for e2e
# testing of kubernetes and managed by boskos

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 [repo...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all projects" > /dev/stderr
    echo "  $0 k8s-infra-node-e2e-project # just do one" > /dev/stderr
    echo > /dev/stderr
}

## setup custom role for prow troubleshooting
color 6 "Ensuring custom org role prow.viewer role exists"
(
    ensure_custom_org_role_from_file "prow.viewer" "${SCRIPT_DIR}/roles/prow.viewer.yaml"
) 2>&1 | indent

## setup service accounts and ips for the prow build cluster

PROW_BUILD_SVCACCT=$(svc_acct_email "k8s-infra-prow-build" "prow-build")
BOSKOS_JANITOR_SVCACCT=$(svc_acct_email "k8s-infra-prow-build" "boskos-janitor")

color 6 "Ensuring boskos-janitor is empowered"
(
color 6 "Ensuring external ip address exists for boskos-metrics service in prow build cluster"
# this is so monitoring.prow.k8s.io is able to scrape metrics from boskos
ensure_regional_address \
  "k8s-infra-prow-build" \
  "us-central1" \
  "boskos-metrics" \
  "to allow monitoring.k8s.prow.io to scrape boskos metrics"
) 2>&1 | indent

color 6 "Ensuring greenhouse is empowered"
(
ensure_regional_address \
  "k8s-infra-prow-build" \
  "us-central1" \
  "greenhouse-metrics" \
  "to allow monitoring.k8s.prow.io to scrape greenhouse metrics"
) 2>&1 | indent

## setup projects to be used by e2e tests for standing up clusters

E2E_MANUAL_PROJECTS=(
  # for manual use during node-e2e job migration, eg: --gcp-project=gce-project
  k8s-infra-e2e-gce-project
  # for manual use during job migration, eg: --gcp-project=node-e2e-project
  k8s-infra-e2e-node-e2e-project
  # for manual use during job migration, eg: --gcp-project=scale-project
  k8s-infra-e2e-scale-project
  # for manual use during job migration, eg: --gcp-project=gpu-project
  k8s-infra-e2e-gpu-project
  # for manual use during job migration, eg: --gcp-project=ingress-project
  k8s-infra-e2e-ingress-project
)

# general purpose e2e projects, no quota changes
E2E_BOSKOS_PROJECTS=()
for i in $(seq 1 120); do
  E2E_BOSKOS_PROJECTS+=($(printf "k8s-infra-e2e-boskos-%03i" $i))
done

# e2e projects for scalability jobs
# - us-east1 cpu quota raised to 125
# - us-east1 in-use addresses quota raised to 125
E2E_SCALE_PROJECTS=()
for i in $(seq 1 5); do
  E2E_SCALE_PROJECTS+=($(printf "k8s-infra-e2e-boskos-scale-%02i" $i))
done

# e2e projects for gpu jobs
# - us-west1 Committed NVIDIA K80 GPUs raised to 2
E2E_GPU_PROJECTS=()
for i in $(seq 1 10); do
  E2E_GPU_PROJECTS+=($(printf "k8s-infra-e2e-boskos-gpu-%02i" $i))
done

E2E_PROJECTS=(
  "${E2E_MANUAL_PROJECTS[@]}"
  "${E2E_BOSKOS_PROJECTS[@]}"
  "${E2E_SCALE_PROJECTS[@]}"
  "${E2E_GPU_PROJECTS[@]}"
)

if [ $# = 0 ]; then
    # default to all e2e projects
    set -- "${E2E_PROJECTS[@]}"
fi

color 6 "Ensuring e2e projects exist and are appropriately configured"
for prj; do
  color 6 "Ensuring e2e project exists and is appropriately configured: ${prj}"
  (
    ensure_project "${prj}"

    color 6 "Enabling APIs necessary for kubernetes e2e jobs to use e2e project: ${prj}"
    enable_api "${prj}" compute.googleapis.com
    enable_api "${prj}" logging.googleapis.com
    enable_api "${prj}" monitoring.googleapis.com
    enable_api "${prj}" storage-component.googleapis.com

    color 6 "Empower prow-build service account to edit e2e project: ${prj}"
    # TODO: this is what prow.k8s.io uses today, but it is likely over-permissioned, we could
    #       look into creating a more constrained IAM role and using that instead
    gcloud \
      projects add-iam-policy-binding "${prj}" \
      --member "serviceAccount:${PROW_BUILD_SVCACCT}" \
      --role roles/editor

    color 6 "Empower boskos-janitor service account to clean e2e project: ${prj}"
    # TODO: this is what prow.k8s.io uses today, but it is likely over-permissioned, we could
    #       look into creating a more constrained IAM role and using that instead
    gcloud \
      projects add-iam-policy-binding "${prj}" \
      --member "serviceAccount:${BOSKOS_JANITOR_SVCACCT}" \
      --role roles/editor

    color 6 "Empower k8s-infra-prow-oncall@kubernetes.io to admin e2e project: ${prj}"
    # TODO: this is what prow.k8s.io uses today, but it is likely over-permissioned, we could
    #       look into creating a more constrained IAM role and using that instead
    gcloud \
      projects add-iam-policy-binding "${prj}" \
      --member "group:k8s-infra-prow-oncall@kubernetes.io" \
      --role roles/owner

    color 6 "Empower k8s-infra-prow-viewers@kubernetes.io to view e2e project: ${prj}"
    gcloud \
      projects add-iam-policy-binding "${prj}" \
      --member "group:k8s-infra-prow-viewers@kubernetes.io" \
      --role $(custom_org_role_name "prow.viewer")
    
    if [[ "${prj}" =~ k8s-infra-e2e.*scale ]]; then
      color 6 "Empower k8s-infra-sig-scalability-oncall@kubernetes.io to admin e2e project: ${prj}"
      gcloud \
        projects add-iam-policy-binding "${prj}" \
        --member "group:k8s-infra-sig-scalability-oncall@kubernetes.io" \
        --role roles/owner
    fi

    color 6 "Ensure prow-build prowjobs are able to ssh to instances in e2e project: ${prj}"
    # TODO: this is what prow.k8s.io does today, we could look into use OS Login instead
    prow_build_ssh_pubkey="prow:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCmYxHh/wwcV0P1aChuFLpl28w6DFyc7G5Xrw1F8wH1Re9AdxyemM2bTZ/PhsP3u9VDnNbyOw3UN00VFdumkFLjLf1WQ7Q6rZDlPjlw7urBIvAMqUecY6ae1znqsZ0dMBxOuPXHznlnjLjM5b7O7q5WsQMCA9Szbmz6DsuSyCuX0It2osBTN+8P/Fa6BNh3W8AF60M7L8/aUzLfbXVS2LIQKAHHD8CWqvXhLPuTJ03iSwFvgtAK1/J2XJwUP+OzAFrxj6A9LW5ZZgk3R3kRKr0xT/L7hga41rB1qy8Uz+Xr/PTVMNGW+nmU4bPgFchCK0JBK7B12ZcdVVFUEdpaAiKZ prow"

    # append to project-wide ssh-keys metadata if not present
    ssh_pubkeys=$(mktemp "/tmp/${prj}-ssh-keys-XXXX")
    gcloud compute project-info describe --project="${prj}" --format=json | \
      jq -r '(.commonInstanceMetadata.items//[])[]|select(.key=="ssh-keys").value' > "${ssh_pubkeys}"
    if ! grep -q "${prow_build_ssh_pubkey}" "${ssh_pubkeys}"; then
      echo "${prow_build_ssh_pubkey}" >> "${ssh_pubkeys}"
      gcloud compute project-info add-metadata --project="${prj}" \
        --metadata-from-file ssh-keys="${ssh_pubkeys}"
    fi

  ) 2>&1 | indent
done 2>&1 | indent
