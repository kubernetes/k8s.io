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

# This script ensures terraform service accounts for prow jobs and GCB are created.
# DOCS: https://cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts#cross-project_set_up

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
PROJECT=$(k8s_infra_project "prow" "k8s-infra-terraform")

color 6 "Ensuring project exists: ${PROJECT}"
ensure_project "${PROJECT}"

PROJECT_SERVICES=(
    iam.googleapis.com
)

# Enable GCB APIs
color 6 "Ensure required services are enabled for: ${PROJECT}"

ensure_only_services "${PROJECT}" "${PROJECT_SERVICES[@]}"

# Create various service accounts for Terraform
color 6 "Creating oci-proxy dev Service Account"
ensure_service_account \
    "${PROJECT}" \
    "oci-proxy-dev" \
    "oci proxy dev Terraform Account"

color 6 "Creating oci-proxy prod Service Account"
ensure_service_account \
    "${PROJECT}" \
    "oci-proxy-prod" \
    "oci proxy prod Terraform Account"

oci_proxy_dev_account="$(svc_acct_email "${project}" "${STAGING_SIGNER_SVCACCT}")"
color 6 "Ensuring GCB service agent of k8s-staging-infra-tools can impersonate ${oci_proxy_dev_account} "
ensure_serviceaccount_role_binding \
    "${oci_proxy_dev_account}" \
    "serviceAccount:service-1017132094926@gcp-sa-cloudbuild.iam.gserviceaccount.com" \
    "roles/iam.serviceAccountTokenCreator"

oci_proxy_prod_account="$(svc_acct_email "${project}" "${STAGING_SIGNER_SVCACCT}")"
color 6 "Ensuring GCB service agent of k8s-staging-infra-tools can impersonate ${oci_proxy_prod_account} "
ensure_serviceaccount_role_binding \
    "${oci_proxy_prod_account}" \
    "serviceAccount:service-1017132094926@gcp-sa-cloudbuild.iam.gserviceaccount.com" \
    "roles/iam.serviceAccountTokenCreator"

color 6 "Empowering ${oci_proxy_dev_account} on the k8s-infra-oci-proxy project"
ensure_project_role_binding "${PROJECT}" "serviceAccount:${oci_proxy_dev_account}" "roles/owner"

color 6 "Empowering ${oci_proxy_dev_account} on the k8s-infra-oci-proxy-prod project"
ensure_project_role_binding "${PROJECT}" "serviceAccount:${oci_proxy_prod_account}" "roles/owner"

