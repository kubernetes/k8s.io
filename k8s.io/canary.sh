#!/bin/sh

set -o errexit
set -o nounset
set -o pipefail

alias kc="kubectl --context=utilicluster --namespace=k8s-io-canary"

kc apply \
    -f configmap-nginx.yaml \
    -f configmap-www-get.yaml \
    -f configmap-www-golang.yaml \
    -f deployment.yaml \
    -f service-canary.yaml

sleep 5

make test TARGET_IP=104.197.208.221
