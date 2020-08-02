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

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "${SCRIPT_DIR}/lib.sh"

PROD_ZONES=(
    k8s.io.
    kubernetes.io.
    x-k8s.io.
    k8s-e2e.com.
    k8s.dev.
    kubernetes.dev.
)

CANARY_ZONES=("${PROD_ZONES[@]/#/canary.}")

ALL_ZONES=(
    "${CANARY_ZONES[@]}"
    "${PROD_ZONES[@]}"
)

DRY_RUN=false
OCTODNS_CONFIG="octodns-config.yaml"
LOGS_PATH="${ARTIFACTS:-.}"

# Checking if octodns-sync is present as without it there is no sense to proceed
if ! command -v octodns-sync &> /dev/null; then
    echo "Couldn't find octodns-sync"
    exit 1
fi

# Checking if LOGS_PATH is an existing directory and if we can write to it.
# Failing otherwise
if [[ ! -d "${LOGS_PATH}" ]] || [[ ! -w "${LOGS_PATH}" ]]; then
    echo "Can't write to LOGS_PATH (${LOGS_PATH}). Aborting"
    exit 1
fi

# Assumes to be running in a checked-out git repo directory, and in the same
# subdirectory as this file.
if [[ ! -f "${OCTODNS_CONFIG}" ]] || [[ ! -d zone-configs ]]; then
    echo "CWD does not appear to have the configs needed: $(pwd)"
    exit 1
fi

# Where to hold processed configs for this run.
TMPCFG=$(mktemp -d /tmp/octodns.XXXXXX)
# Where to hold processed octodns config file with providers.config.directory
# set to directory with processed zone configs
TMP_OCTODNS_CFG=$(mktemp /tmp/octodns.XXXXXX)

echo "Using ${TMP_OCTODNS_CFG} as octodns config file"
precook_octodns_config "${OCTODNS_CONFIG}" "${TMPCFG}" "${TMP_OCTODNS_CFG}"

function parse_args() {
  # positional args
  args=()

  # named args
  while [ "$#" -gt 0 ]; do
      case "$1" in
          -d | --dry-run )          DRY_RUN=true;           ;;
          * )                       args+=("$1")            # if no match, add it to the positional args
      esac
      shift # move to next kv pair
  done

  # restore positional args
  set -- "${args[@]}"
}

parse_args "$@";

# Pushes config to zones.
#   args: args to pass to octodns (e.g. --doit, --force, a list of zones)
push () {
    octodns-sync \
        --config-file="${TMP_OCTODNS_CFG}" \
        --log-stream-stdout \
        --debug \
        "$@"
}

# Pre-cook our configs into $TMPCFG. Some zones have multiple files that need
# to be joined, for example.
echo "Using ${TMPCFG}/ for cooked config files"
precook_zone_configs "${TMPCFG}" "${ALL_ZONES[@]}"

# Push to canaries.
echo "Dry-run to canary zones"
push "${CANARY_ZONES[@]}" > "${LOGS_PATH}/log.canary" 2>&1
if [ $? != 0 ]; then
    echo "Canary dry-run FAILED, halting; log follows:"
    echo "========================================="
    cat "${LOGS_PATH}/log.canary"
    exit 2
fi

if [ "${DRY_RUN}" = false ]; then
  echo "Pushing to canary zones"
  push --doit "${CANARY_ZONES[@]}" >> "${LOGS_PATH}/log.canary" 2>&1
  if [ $? != 0 ]; then
      echo "Canary push FAILED, halting; log follows:"
      echo "========================================="
      cat "${LOGS_PATH}/log.canary"
      exit 2
  fi
  echo "Canary push SUCCEEDED"

  for zone in "${CANARY_ZONES[@]}"; do
      TRIES=12
      echo "Testing canary zone: $zone"
      for i in $(seq 1 "$TRIES"); do
          ./check-zone.sh -c "${TMPCFG}" -o "${TMP_OCTODNS_CFG}" \
            "$zone" >> "${LOGS_PATH}/log.canary" 2>&1
          if [ $? == 0 ]; then
              break
          fi
          if [ $i != "$TRIES" ]; then
              echo "  test failed, might be propagation delay, will retry..."
              sleep 10
          else
              echo "Canary test FAILED, halting; log follows:"
              echo "========================================="
              cat "${LOGS_PATH}/log.canary"
              exit 2
          fi
      done
      echo "Canary $zone SUCCEEDED"
  done
fi

# Push to prod.
echo "Dry-run to prod zones"
push "${PROD_ZONES[@]}" > "${LOGS_PATH}/log.prod" 2>&1
if [ $? != 0 ]; then
    echo "Prod dry-run FAILED, halting; log follows:"
    echo "========================================="
    cat "${LOGS_PATH}/log.prod"
    exit 3
fi

if [ "${DRY_RUN}" = false ]; then
  echo "Pushing to prod zones"
  push --doit "${PROD_ZONES[@]}" >> "${LOGS_PATH}/log.prod" 2>&1
  if [ $? != 0 ]; then
      echo "Prod push FAILED, halting; log follows:"
      echo "========================================="
      cat "${LOGS_PATH}/log.prod"
      exit 3
  fi
  echo "Prod push SUCCEEDED"

  for zone in "${PROD_ZONES[@]}"; do
      TRIES=12
      echo "Testing prod zone: $zone"
      for i in $(seq 1 "$TRIES"); do
          ./check-zone.sh -c "${TMPCFG}" -o "${TMP_OCTODNS_CFG}" \
            "$zone" >> "${LOGS_PATH}/log.prod" 2>&1
          if [ $? == 0 ]; then
              break
          fi
          if [ $i != "$TRIES" ]; then
              echo "  test failed, might be propagation delay, will retry..."
              sleep 10
          else
              echo "Prod test FAILED, halting; log follows:"
              echo "========================================="
              cat "${LOGS_PATH}/log.prod"
              exit 2
          fi
      done
      echo "Prod $zone SUCCEEDED"
  done
fi
