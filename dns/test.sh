#!/bin/bash
#
# Test for Kubernetes DNS.
#
# $1: "canary" or "prod"

# set -x
# set -e

if [ "$1" != "canary" -a "$1" != "prod" ]; then
    echo "usage: $0 <canary|prod>"
    exit 1
fi

if [ "$1" == "canary" ]; then
    ZONE_PFX="canary."
else # "prod"
    ZONE_PFX=""
fi

function domain_to_zone() {
    gcloud dns managed-zones list --format=flattened --format='value(name)' --filter="dnsName=$1"
}

function get_zone_dns() {
    gcloud dns managed-zones describe $1 --format='value(nameServers[0])'
}

function check_zone() {
    DOMAIN=$1
    GCLOUD_ZONE=$(domain_to_zone $DOMAIN)
    DNS_SERVER=$(get_zone_dns $GCLOUD_ZONE)
    echo "Testing ${DOMAIN} via ${GCLOUD_ZONE} @${DNS_SERVER}"
    docker run -ti \
           -u `id -u` \
           -v ~/.config/gcloud:/.config/gcloud:ro \
           -v `pwd`/octodns-config.yaml:/octodns/config.yaml:ro \
           -v `pwd`/zone-configs:/octodns/config:ro \
           ${USER}/octodns \
           check-zone \
           --config-file=/octodns/config.yaml \
           --zone $1 \
           --source config \
           $DNS_SERVER \
        || (RESULT=$? && (echo FAIL ;exit $RESULT))
}
check_zone "${ZONE_PFX}k8s.io." || exit $?
check_zone "${ZONE_PFX}kubernetes.io." || exit $?

echo PASS
