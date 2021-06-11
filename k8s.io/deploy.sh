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

if [ $# -ne 1 ] || [ -z "${1:-}" ]; then
    echo "usage: $0 [ canary | prod ]"
    exit 1
fi
if [ "$1" != "canary" ] && [ "$1" != "prod" ]; then
    echo "unsupported target '$1'"
    echo "usage: $0 [ canary | prod ]"
    exit 1
fi

NS="k8s-io-$1"
CONTEXT="gke_kubernetes-public_us-central1_aaa"

echo "Deploying to namespace $NS - ^C now to abort..."
sleep 5

function kc() {
  kubectl --context="${CONTEXT}" --namespace="${NS}" "$@"
}

kc apply \
    -f configmap-nginx.yaml \
    -f configmap-www-get.yaml \
    -f deployment.yaml \
    -f service.yaml

kc rollout restart deployment k8s-io

echo "waiting for all replicas to be up"
while true; do
  sleep 3
  read -r WANT HAVE UNAVAIL < <( \
      kc get deployment k8s-io \
          -o go-template='{{.spec.replicas}} {{.status.readyReplicas}} {{.status.unavailableReplicas}}{{"\n"}}'
  )

  if [ -z "${HAVE}" ] || [ "${HAVE}" == "<no value>" ]; then
      HAVE=0
  fi
  if [ -z "${UNAVAIL}" ] || [ "${UNAVAIL}" == "<no value>" ]; then
      UNAVAIL=0
  fi
  if [ -n "${WANT}" ] && [ -n "${HAVE}" ] && [ "${WANT}" == "${HAVE}" ] && [ "${UNAVAIL}" == 0 ]; then
    break
  fi
  echo "  want ${WANT}, found ${HAVE} ready and ${UNAVAIL} unavailable"
done

# We can only test IPv4 from within GCP.
all_ips=$(kc get ing k8s-io -o go-template='{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}')

for ip in $all_ips; do
    echo "Testing TARGET_IP=$ip"
    make test TARGET_IP="$ip"
done
