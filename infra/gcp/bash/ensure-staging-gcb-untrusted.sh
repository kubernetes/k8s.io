#!/usr/bin/env bash

# Copyright 2022 The Kubernetes Authors.
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

# This script creates & configures the project used for running untrusted cloudbuild jobs.

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

# The GCP project name.
PROJECT=$(k8s_infra_project "staging" "k8s-staging-gcb-untrusted")

# The service account name in $PROJECT.
GCB_SVCACCT="image-builder"


color 6 "Ensuring project exists: ${PROJECT}"
ensure_project "${PROJECT}"

GCB_PROJECT_SERVICES=(
    cloudbuild.googleapis.com
)

# Enable GCB APIs
color 6 "Ensure services necessary for Cloud Build are enabled for: ${PROJECT}"

ensure_only_services "${PROJECT}" "${GCB_PROJECT_SERVICES[@]}"

# Create a service account for GCB to grant access to.
color 6 "Creating service account for ${GCB_SVCACCT}"
ensure_service_account \
    "${PROJECT}" \
    "${GCB_SVCACCT}" \
    "Used by prow to run cloudbuild jobs on this project"

# Allow the image-builder service account to submit jobs to this project. https://cloud.google.com/build/docs/iam-roles-permissions#permissions
color 6 "Empowering ${GCB_SVCACCT}"
ensure_project_role_binding "${PROJECT}" "serviceAccount:$(svc_acct_email "${PROJECT}" "${GCB_SVCACCT}")" "roles/cloudbuild.builds.editor"

# Allow k8s-infra-prow-build to run pods as this service account
color 6 "Ensuring GKE clusters in 'k8s-infra-prow-build' can run pods in '${PROWJOB_POD_NAMESPACE}' as '${GCB_SVCACCT}'"
empower_gke_for_serviceaccount \
    "k8s-infra-prow-build" \
    "${PROWJOB_POD_NAMESPACE}" \
    "$(svc_acct_email "${PROJECT}" "${GCB_SVCACCT}")" \
    image-tester
