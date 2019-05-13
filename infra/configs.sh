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

# The name of the GCP project
# TODO ameukam: (use kubernetes-public instead)
PROJECT="k8s-infra-dev-cluster-turnup"

# The name of the GKE cluster
# TODO wg-k8s-infra: define nomenclature for the name
NAME="${NAME:-gke-cluster}"

# The IAM service acccount for GKE
SVC_ACCOUNT="gke-node-sa"

# The BigQuery dataset name for billing data (don't support special characters  such as -, &, @, or %)
DATASET_NAME="k8s_cluster_test_billing"

# The name of the GCP region where the cluster will be created
REGION="${REGION:-us-central1}"

# The Version the GKE cluster
CLUSTER_VERSION="gcloud beta container get-server-config --project=${NAME} --region=${REGION} --format='value(validMasterVersions[0])'"

# The machine type of the GKE instances.
MACHINE_TYPE=${MACHINE_SIZE:-n1-standard-4}

# The disk type of the GKE instances
DISK_TYPE=${DISK_TYPE:-pd-ssd}

# The number of nodes created per cluster's zone.
NUM_NODES="${NUM_NODES:-1}"

# The IPv4 CIDR range to use for the master network. This should have a netmask size of /28.
MASTER_IPV4_CIDR="172.16.0.0/28"

NODE_IP_RANGE="192.168.0.0/24"

# Number of Pods that can run on this node.
MAX_PODS_PER_NODE=${MAX_PODS_PER_NODE:-110}

# The list of access scopes to enable
SCOPES="${SCOPES:-gke-default}"

# range of authorized networks to access to the API Server
MASTER_IP_RANGE="${MASTER_IP_RANGE:-0.0.0.0/0}"
