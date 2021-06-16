#!/usr/bin/env bash

# Copyright 2021 The Kubernetes Authors.
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

# Deploys this app to the aaa cluster, or whatever cluster is pointed to
# by KUBECTL_CONTEXT if set. Assumes the app's namespace already exists.
#
# Members of k8s-infra-rbac-prow@kubernetes.io can run this.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

app=$(basename "${SCRIPT_ROOT}")

# coordinates to locate the target cluster in gke
cluster_name="aaa"
cluster_project="kubernetes-public"
cluster_region="us-central1"

# coordinates to locate the app on the target cluster
namespace="${app}"

# well known name set by `gcloud container clusters get-credentials`
gke_context="gke_${cluster_project}_${cluster_region}_${cluster_name}"
context="${KUBECTL_CONTEXT:-${gke_context}}"

# ensure we have a context to talk to the target cluster
if ! kubectl config get-contexts "${context}" >/dev/null 2>&1; then
  gcloud container clusters get-credentials "${cluster_name}" --project="${cluster_project}" --region="${cluster_region}"
  context="${gke_context}"
fi

# deploy kubernetes resources
pushd "${SCRIPT_ROOT}" >/dev/null
kubectl --context="${context}" --namespace="${namespace}" apply -Rf cluster/
