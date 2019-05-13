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

# This script creates and configures a private GKE cluster

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/configs.sh"
. "${SCRIPT_DIR}/lib.sh"
. "${SCRIPT_DIR}/utils.sh"

check-install gcloud
check-install kubectl

if [ $# -gt 0 ]; then
  color 4 "Error. too many arguments." >&2
  usage
  exit 1
fi

# Create the project if needed
printf 'Ensuring project exists: %s.\n' "${PROJECT}"
ensure_project "${PROJECT}"

# Enable Kubernetes Engine API
printf 'Enabling the compute API for: %s.\n' "${PROJECT}"
enable_api "${PROJECT}" container.googleapis.com

# Enable BigQuery API
printf 'Enabling the BigQuery API for: %s.\n' "${PROJECT}"
enable_api "${PROJECT}" bigquery-json.googleapis.com

# Create a IAM Service Account the cluster
printf 'Creating IAM service account for: %s.\n' "${NAME}"
ensure-service-account "${PROJECT}" "${SVC_ACCOUNT}"

printf 'Ensuring %s have minimal permissions.\n' "${SVC_ACCOUNT}"
allow-sa-permissions "${PROJECT}" "${SVC_ACCOUNT}"

# Create a dedicated gcp network for the GKE cluster
printf 'Ensuring GCP network: %s.\n' "${NAME}"
create-network "${PROJECT}" "${NAME}"

# Create a dedicated subnet for the GKE cluster
printf 'Ensuring GCP subnet: %s.\n' "${NAME}"
create-subnet "${PROJECT}" "${NAME}"

printf 'Ensuring GCP NAT router: %s.\n' "${NAME}"
create-cloud-nat-router "${PROJECT}" "${NAME}"

# Create a BigQuery dataset that will store cluster usage metering
printf 'Ensuring BigQuery dataset: %s.\n' "${DATASET_NAME}"
create-bigquery-dataset "${PROJECT}" "${DATASET_NAME}"

printf 'Creating GKE cluster: %s.\n' "${NAME}"
create-cluster

printf 'Done.'
