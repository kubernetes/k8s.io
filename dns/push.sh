#!/bin/bash

# This runs as you.  It assumes you have built an image named ${USER}/octodns.

# Pushes config to zones.
#   args: args to pass to octodns (e.g. --doit, --force, a list of zones)
function push() {
    docker run -ti \
        -u `id -u` \
        -v ~/.config/gcloud:/.config/gcloud:ro \
        -v `pwd`/octodns-config.yaml:/octodns/config.yaml:ro \
        -v `pwd`/zone-configs:/octodns/config:ro \
        ${USER}/octodns \
        octodns-sync \
            --config-file=/octodns/config.yaml \
            --log-stream-stdout \
            --debug \
            "$@"
}
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

# Assumes to be running in a checked-out git repo directory, and in the same
# subdirectory as this file.
if [ ! -f octodns-config.yaml -o ! -d zone-configs ]; then
    echo "CWD does not appear to have the configs needed: $(pwd)"
    exit 1
fi

# Push to canaries.
echo "Dry-run to canary zones"
push canary.k8s.io. canary.kubernetes.io. > log.canary 2>&1
if [ $? != 0 ]; then
    echo "Canary dry-run FAILED, halting; log follows:"
    echo "========================================="
    cat log.canary
    exit 2
fi
echo "Pushing to canary zones"
push --doit canary.k8s.io. canary.kubernetes.io. > log.canary 2>&1
if [ $? != 0 ]; then
    echo "Canary push FAILED, halting; log follows:"
    echo "========================================="
    cat log.canary
    exit 2
fi
echo "Canary push SUCCEEDED"

check_zone "canary.k8s.io." || exit $?
check_zone "canary.kubernetes.io." || exit $?
echo "Canary test SUCCEEDED"

# Exit for now until we are ready to push to prod
exit 0
# Push to prod.
echo "Dry-run to prod zones"
push k8s.io. kubernetes.io. > log.prod 2>&1
if [ $? != 0 ]; then
    echo "Prod dry-run FAILED, halting; log follows:"
    echo "========================================="
    cat log.prod
    exit 3
fi
echo "Pushing to prod zones"
push --doit k8s.io. kubernetes.io. > log.prod 2>&1
if [ $? != 0 ]; then
    echo "Prod push FAILED, halting; log follows:"
    echo "========================================="
    cat log.prod
    exit 3
fi
echo "Prod push SUCCEEDED"

# TODO: run test against prod
