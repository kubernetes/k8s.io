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

## setup service accounts and ips for the prow build cluster

# TODO: replace prow-build-test with actual service account
PROW_BUILD_SVCACCT=$(svc_acct_email "kubernetes-public" "prow-build-test")
ensure_service_account \
  "kubernetes-public" \
  "prow-build-test" \
  "used by prowjobs that run in prow-build-test cluster"
# the namespace "test-pods" here must match the namespace defined in prow's config.yaml
# to launch pods defined by prowjobs
# eg: https://github.com/kubernetes/test-infra/blob/master/config/prow/config.yaml#L73
empower_ksa_to_svcacct \
  "kubernetes-public.svc.id.goog[test-pods/prow-build]" \
  "kubernetes-public" \
  "${PROW_BUILD_SVCACCT}"

# manual parts: 
# - create key, add to prow-build-test as service-account secret
# - gsutil iam ch serviceAccount:$PROW_BUILD_SVCACCT:objectAdmin gs://bashfire-prow
# - gsutil iam ch serviceAccount:$PROW_BUILD_SVCACCT:objectCreator gs://bashfire-prow

# TODO: replace boskos-janitor-test with actual service account
BOSKOS_JANITOR_SVCACCT=$(svc_acct_email "kubernetes-public" "boskos-janitor-test")
ensure_service_account \
  "kubernetes-public" \
  "boskos-janitor-test" \
  "used by boskos-janitor in prow-build-test cluster"
# the namespace "test-pods" here must match the namespace defined in prows config.yaml
# to launch pods defined by prowjobs because most prowjobs as-written assume they can
# talk to either http://boskos (kubetest or bootstrap.py jobs) or 
# https://boskos.svc.test-pods.cluster.local (some of the cluster-api jobs), and so
# all boskos components are deployed to this namespace
empower_ksa_to_svcacct \
  "kubernetes-public.svc.id.goog[test-pods/boskos-janitor]" \
  "kubernetes-public" \
  "${BOSKOS_JANITOR_SVCACCT}"
ensure_regional_address \
  "kubernetes-public" \
  "us-central1" \
  "boskos-metrics" \
  "to allow monitoring.k8s.prow.io to scrape boskos metrics"

## setup projects to be used by e2e tests for standing up clusters

# TODO: replace spiffxp- projects with actual projects
E2E_PROJECTS=(
  # for manual use during node-e2e job migration, eg: --gcp-project=spiffxp-node-e2e-project
  spiffxp-node-e2e-project
  # for manual use during job migration, eg: --gcp-project=spiffxp-gce-project
  spiffxp-gce-project
  # managed by boskos, part of the gce-project pool, eg: --gcp-project-type=gce-project
  spiffxp-boskos-project-01
  spiffxp-boskos-project-02
  spiffxp-boskos-project-03
)

if [ $# = 0 ]; then
    # default to all e2e projects
    set -- "${E2E_PROJECTS[@]}"
fi

for prj; do
  # create the project
  ensure_project "${prj}"

  # enable the necessary apis
  enable_api "${prj}" compute.googleapis.com
  enable_api "${prj}" logging.googleapis.com
  enable_api "${prj}" storage-component.googleapis.com

  # empower prow to do what it needs within the project
  gcloud \
    projects add-iam-policy-binding "${prj}" \
    --member "serviceAccount:${PROW_BUILD_SVCACCT}" \
    --role roles/editor

  # empower boskos-janitor to clean projects
  gcloud \
    projects add-iam-policy-binding "${prj}" \
    --member "serviceAccount:${BOSKOS_JANITOR_SVCACCT}" \
    --role roles/editor

  # empower prowjobs in build cluster to ssh to nodes within projects
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
done
