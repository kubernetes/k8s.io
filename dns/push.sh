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
push --doit canary.k8s.io. canary.kubernetes.io. >> log.canary 2>&1
if [ $? != 0 ]; then
    echo "Canary push FAILED, halting; log follows:"
    echo "========================================="
    cat log.canary
    exit 2
fi
echo "Canary push SUCCEEDED"

echo "Testing canary zones"
./check-zone.sh "canary.k8s.io." >> log.canary 2>&1
if [ $? != 0 ]; then
    echo "Canary test FAILED, halting; log follows:"
    echo "========================================="
    cat log.canary
    exit 2
fi
./check-zone.sh "canary.kubernetes.io." >> log.canary 2>&1
if [ $? != 0 ]; then
    echo "Canary test FAILED, halting; log follows:"
    echo "========================================="
    cat log.canary
    exit 2
fi
echo "Canary test SUCCEEDED"

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
push --doit k8s.io. kubernetes.io. >> log.prod 2>&1
if [ $? != 0 ]; then
    echo "Prod push FAILED, halting; log follows:"
    echo "========================================="
    cat log.prod
    exit 3
fi
echo "Prod push SUCCEEDED"

echo "Testing prod zones"
./check-zone.sh "k8s.io." >> log.prod 2>&1
if [ $? != 0 ]; then
    echo "Prod test FAILED, halting; log follows:"
    echo "========================================="
    cat log.prod
    exit 2
fi
./check-zone.sh "kubernetes.io." >> log.prod 2>&1
if [ $? != 0 ]; then
    echo "Production test FAILED, halting; log follows:"
    echo "========================================="
    cat log.prod
    exit 2
fi
echo "Canary test SUCCEEDED"

echo "Prod test SUCCEEDED"
