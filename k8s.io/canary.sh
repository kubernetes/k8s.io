#!/usr/bin/env bash

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
