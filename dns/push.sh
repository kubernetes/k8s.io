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
# This runs as you.  It assumes you have built an image named ${USER}/octodns.

PROD_ZONES=(
    k8s.io.
    kubernetes.io.
    x-k8s.io.
    k8s-e2e.com.
)

CANARY_ZONES=("${PROD_ZONES[@]/#/canary.}")

ALL_ZONES=(
    "${CANARY_ZONES[@]}"
    "${PROD_ZONES[@]}"
)

# Pushes config to zones.
#   args: args to pass to octodns (e.g. --doit, --force, a list of zones)
push () {
    docker run -ti \
        -u `id -u` \
        -v ~/.config/gcloud:/.config/gcloud:ro \
        -v `pwd`/octodns-config.yaml:/octodns/config.yaml:ro \
        -v "${TMPCFG}":/octodns/config:ro \
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

# Where to hold processed configs for this run.
TMPCFG=$(mktemp -d /tmp/octodns.XXXXXX)

# Pre-cook our configs into $TMPCFG.  Some zones have multiple files that need
# to be joined, for example.
echo "Using ${TMPCFG} for cooked config files"
for z in "${ALL_ZONES[@]}"; do
    # Every zone should have 1 file $z.yaml or N files $z._*.yaml.
    # $z already ends in a period.
    cat zone-configs/${z}yaml zone-configs/${z}_*.yaml \
        > "${TMPCFG}/${z}yaml" 2>/dev/null
    if [ ! -s "${TMPCFG}/${z}yaml" ]; then
        echo "${TMPCFG}/${z}yaml appears to be empty after pre-processing!"
        exit 1
    fi
done

# Push to canaries.
echo "Dry-run to canary zones"
push "${CANARY_ZONES[@]}" > log.canary 2>&1
if [ $? != 0 ]; then
    echo "Canary dry-run FAILED, halting; log follows:"
    echo "========================================="
    cat log.canary
    exit 2
fi
echo "Pushing to canary zones"
push --doit "${CANARY_ZONES[@]}" >> log.canary 2>&1
if [ $? != 0 ]; then
    echo "Canary push FAILED, halting; log follows:"
    echo "========================================="
    cat log.canary
    exit 2
fi
echo "Canary push SUCCEEDED"

for zone in "${CANARY_ZONES[@]}"; do
    TRIES=12
    echo "Testing canary zone: $zone"
    for i in $(seq 1 "$TRIES"); do
        ./check-zone.sh -c "${TMPCFG}" "$zone" >> log.canary 2>&1
        if [ $? == 0 ]; then
            break
        fi
        if [ $i != "$TRIES" ]; then
            echo "  test failed, might be propagation delay, will retry..."
            sleep 10
        else
            echo "Canary test FAILED, halting; log follows:"
            echo "========================================="
            cat log.canary
            exit 2
        fi
    done
    echo "Canary $zone SUCCEEDED"
done

# Push to prod.
echo "Dry-run to prod zones"
push "${PROD_ZONES[@]}" > log.prod 2>&1
if [ $? != 0 ]; then
    echo "Prod dry-run FAILED, halting; log follows:"
    echo "========================================="
    cat log.prod
    exit 3
fi

echo "Pushing to prod zones"
push --doit "${PROD_ZONES[@]}" >> log.prod 2>&1
if [ $? != 0 ]; then
    echo "Prod push FAILED, halting; log follows:"
    echo "========================================="
    cat log.prod
    exit 3
fi
echo "Prod push SUCCEEDED"

for zone in "${PROD_ZONES[@]}"; do
    TRIES=12
    echo "Testing prod zone: $zone"
    for i in $(seq 1 "$TRIES"); do
        ./check-zone.sh -c "${TMPCFG}" "$zone" >> log.prod 2>&1
        if [ $? == 0 ]; then
            break
        fi
        if [ $i != "$TRIES" ]; then
            echo "  test failed, might be propagation delay, will retry..."
            sleep 10
        else
            echo "Prod test FAILED, halting; log follows:"
            echo "========================================="
            cat log.prod
            exit 2
        fi
    done
    echo "Prod $zone SUCCEEDED"
done
