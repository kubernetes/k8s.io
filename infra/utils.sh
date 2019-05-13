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

function allow-sa-permissions() {
    if [ $# -lt 1 ] && [ $# -gt 2 ] && [ -z "$1" ]; then
        printf "allow-sa-permissions(project, account) requires 1 or 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local account="$2"
    local full_name_account=$(svc_acct_for "${project}" "${account}")
    gcloud projects add-iam-policy-binding "${project}" \
        --member "serviceAccount:${full_name_account}" \
        --role roles/logging.logWriter
    gcloud projects add-iam-policy-binding "${project}" \
        --member "serviceAccount:${full_name_account}" \
        --role roles/monitoring.viewer
    gcloud projects add-iam-policy-binding "${project}" \
        --member "serviceAccount:${full_name_account}" \
        --role roles/monitoring.metricWriter
}

# Ensure the program is installed
function check-install() {
    if ! command -v "${1}" &>/dev/null; then
        color 4 "You don't have ${1} installed. Please install ${1}."
        exit 1
    fi
}

# Create a BiqQuery Dataset for usage metering
# $1 : The GCP project name
# $2 : The BigQuery dataset name
# $3 : The dataset region (optional)
function create-bigquery-dataset() {
    if [ $# -lt 1 ] && [ $# -gt 2 ] && [ -z "$1" ]; then
        printf "create-bigquery-dataset(project, dataset_name) requires 1 or 2 arguments" >&2
        return 1
    fi
    local -r project="$1"
    local -r dataset_name="$2"
    local -r region="${US:-}"
    if ! bq --project "${project}" ls "${dataset_name}" >/dev/null 2>&1; then
        bq mk --project_id="${project}" --location="${region}" "${dataset_name}"
    else
        printf "Found existing %s dataset.\n" "${dataset_name}"
    fi
}

function create-cluster() {
    gcloud beta container clusters create "${NAME}" \
        --project "${PROJECT}" \
        --region "${REGION}" \
        --machine-type "${MACHINE_TYPE}" \
        --disk-type "${DISK_TYPE}" \
        --cluster-version "${CLUSTER_VERSION}" \
        --num-nodes "${NUM_NODES}" \
        --enable-network-policy \
        --scopes "${SCOPES}" \
        --network "${NAME}" \
        --subnetwork "${NAME}-custom-subnet" \
        --enable-ip-alias \
        --enable-private-nodes \
        --enable-master-authorized-networks \
        --master-ipv4-cidr "${MASTER_IPV4_CIDR}" \
        --master-authorized-networks "${MASTER_IP_RANGE}" \
        --max-pods-per-node "${MAX_PODS_PER_NODE}" \
        --no-issue-client-certificate \
        --metadata disable-legacy-endpoints=true \
        --service-account "$(svc_acct_for "${PROJECT}" "${SVC_ACCOUNT}")" \
        --security-group "gke-security-groups@kubernetes.io" \
        --enable-stackdriver-kubernetes \
        --resource-usage-bigquery-dataset "${DATASET_NAME}" \
        --quiet

    if ! gcloud beta container clusters describe test-cluster --format="value(resourceUsageExportConfig)" >/dev/null 2>&1; then
        gcloud beta container clusters update "${NAME}" --region "${REGION}" --resource-usage-bigquery-dataset "${DATASET_NAME}"
    fi
}

# Sets up Cloud NAT for the network.
# Assumed vars:
#   NETWORK_PROJECT
#   REGION
#   NETWORK
function create-cloud-nat-router() {
    if [ $# -lt 1 ] && [ $# -gt 2 ] && [ -z "$1" ]; then
        printf "create-cloud-nat-router(project, network, region) requires 2 or 3 arguments" >&2
        return 1
    fi
    local -r project="${1}"
    local -r network="${2}"
    local router_name="$network-nat-router"
    local nat_name="$network-nat-config"
    local region=${region:=us-central1}

    if ! gcloud --project "${project}" compute routers describe "${router_name}" &>/dev/null; then
        gcloud --project "${project}" compute routers create "${router_name}" \
            --region "${region}" \
            --network "${network}"
    else
        printf "Found existing CloudNAT router : %s.\n" "${router_name}"
    fi

    if ! gcloud --project "${project}" compute routers nats describe "${nat_name}" --router "${router_name}" &>/dev/null; then
        gcloud --project "${project}" compute routers nats create "${nat_name}" \
            --router-region "${region}" \
            --router "${router_name}" \
            --nat-all-subnet-ip-ranges \
            --auto-allocate-nat-external-ips
    else
        printf "Found existing NAT route : %s.\n" "${nat_name}"
    fi
}

function create-network() {

    local project="$1"
    local network_name="$2"
    if ! gcloud --project "${project}" compute networks describe "${network_name}" &>/dev/null; then
        gcloud --project "${project}" compute networks create "${network_name}" --subnet-mode custom
    else
        printf "Found existing network: %s.\n" "${network_name}"
    fi
}

function create-subnet() {

    local project="$1"
    local subnet_name="$2"
    if ! gcloud --project "${project}" compute networks subnets describe "${subnet_name}-custom-subnet" >/dev/null 2>&1; then
        gcloud --project "${project}" compute networks subnets create "${subnet_name}-custom-subnet" \
            --network "${NAME}" \
            --region "${REGION}" \
            --range "${NODE_IP_RANGE}" \
            --enable-private-ip-google-access
    else
        printf "Found existing subnet: %s.\n" "${subnet_name}"
    fi
}

function ensure-service-account() {
    if [ $# -lt 1 ] && [ $# -gt 2 ] && [ -z "$1" ]; then
        printf "ensure-service-account(account) requires 1 argument" >&2
        return 1
    fi
    local project="$1"
    local account="$2"
    local full_name_account=$(svc_acct_for "${project}" "${account}")
    if ! gcloud --project "${project}" iam service-accounts describe "${full_name_account}" >/dev/null 2>&1; then
        gcloud --project "${project}" iam service-accounts create "${account}" --display-name "${account}"
    else
        printf "Found existing service account: %s.\n" "${full_name_account}"
    fi
}

function usage() {
    printf 'usage: %s' "$0" >/dev/stderr
    echo >/dev/stderr
}
