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

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

app=$(basename "${SCRIPT_ROOT}")

# coordinates to locate the target cluster in gke
cluster_name="aaa"
cluster_project="kubernetes-public"
cluster_region="us-central1"

# well known name set by `gcloud container clusters get-credentials`
gke_context="gke_${cluster_project}_${cluster_region}_${cluster_name}"
context="${KUBECTL_CONTEXT:-${gke_context}}"

# ensure we have a context to talk to the target cluster
if ! kubectl config get-contexts "${context}" >/dev/null 2>&1; then
    gcloud container clusters get-credentials "${cluster_name}" --project="${cluster_project}" --region="${cluster_region}"
    context="${gke_context}"
fi

function deploy() {
    local target="$1"
    if [ "${target}" != "prod" ] && [ "${target}" != "canary" ]; then
        echo >&2 "ERROR: unknown target: ${target}; valid targets are: prod, canary"
        return 1
    fi
    local namespace="k8s-io-$target"

    local kubectl=(
        kubectl
        --context="${context}"
        --namespace="${namespace}"
    )

    echo "running kubectl apply..."
    "${kubectl[@]}" apply \
        -f configmap-nginx.yaml \
        -f configmap-www-get.yaml \
        -f deployment.yaml \
        -f service.yaml

    echo "restarting deployment..."
    "${kubectl[@]}" rollout restart deployment k8s-io

    echo "waiting for all replicas to be up..."
    while true; do
      sleep 3
      read -r spec ready unavail < <( \
          "${kubectl[@]}" get deployment k8s-io \
              -o go-template='{{.spec.replicas}} {{.status.readyReplicas}} {{.status.unavailableReplicas}}{{"\n"}}'
      )

      if [ -z "${ready}" ] || [ "${ready}" == "<no value>" ]; then
          ready=0
      fi
      if [ -z "${unavail}" ] || [ "${unavail}" == "<no value>" ]; then
          unavail=0
      fi
      if [ -n "${spec}" ] && [ -n "${ready}" ] && [ "${spec}" == "${ready}" ] && [ "${unavail}" == 0 ]; then
        break
      fi
      echo "  want ${spec}, found ${ready} ready and ${unavail} unavailable"
    done

    # We can only test IPv4 from within GCP.
    all_ips=$("${kubectl[@]}" get ing k8s-io -o go-template='{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}')

    for ip in $all_ips; do
        echo "Testing TARGET_IP=$ip"
        make test TARGET_IP="$ip"
    done
}

function main() {
  pushd "${SCRIPT_ROOT}" >/dev/null
  if [ $# == 1 ]; then
      echo "Deploying ${app} to '$1' target - ^C now to abort..."
      sleep 5
      deploy "$1"
  elif [ $# == 0 ]; then
      echo "Auto-deploying ${app} to canary then prod targets - ^C now to abort..."
      sleep 5
      deploy canary
      deploy prod
  else
      echo >&2 "Usage: $0 [canary|prod]"
  fi 
}

main "$@"
