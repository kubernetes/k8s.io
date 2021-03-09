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

function kc() {
  kubectl --cluster=prod-aaa --namespace=k8s-io-canary "$@"
}

kc apply \
    -f configmap-nginx.yaml \
    -f configmap-www-get.yaml \
    -f deployment.yaml \
    -f service.yaml

kc scale deployment k8s-io --replicas=0
kc scale deployment k8s-io --replicas=1

echo "waiting for all replicas to be up"
while true; do
  sleep 3
  read WANT HAVE < <( \
      kc get deployment k8s-io \
          -o go-template='{{.spec.replicas}} {{.status.readyReplicas}}{{"\n"}}'
  )
  if [ -z "${HAVE}" -o "${HAVE}" == "<no value>" ]; then
      HAVE=0
  fi
  if [ -n "${WANT}" -a -n "${HAVE}" -a "${WANT}" == "${HAVE}" ]; then
    break
  fi
  echo "  want ${WANT}, found ${HAVE} ready"
done

make test TARGET_IP=34.102.239.89

# it needs IPv6 connectivity
# make test TARGET_IP=2600:1901:0:26f3::
