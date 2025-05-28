#!/bin/bash

# Copyright 2025 The Kubernetes Authors.
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

# The network used is 192.168.0.32/21
# Usable Host IP Range:	192.168.32.1 - 192.168.39.254:
# DHCP Range: 192.168.32.10 - 192.168.33.255
# Used IPPool for 40 Projects having 16 IPs each: 192.168.35.0 - 192.168.37.127
function initBoskosResourceUserData() {
  NR="${1}"

  IPS_PER_PROJECT=16
  # Starting at 192.168.35.0 and allowing usage up to 192.168.39.254
  # allows a maximum of 79 projects
  RANGE_START=35

  S2="$(( (NR - 1) * IPS_PER_PROJECT ))"
  E2="$(( (NR * IPS_PER_PROJECT) - 1 ))"

  S1="$(( S2 / 256 ))"
  E1="$(( E2 / 256 ))"
  S2="$(( S2 % 256 ))"
  E2="$(( E2 % 256 ))"

  START="192.168.$(( RANGE_START + S1 )).${S2}"
  END="192.168.$(( RANGE_START + E1 )).${E2}"

  resourceName=$(printf "k8s-infra-e2e-gcp-gcve-project-%03d" "${NR}")

  folder=$(printf "/Datacenter/vm/prow/k8s-infra-e2e-gcp-gcve-project-%03d" "${NR}")
  resourcePool=$(printf "/Datacenter/host/k8s-gcve-cluster/Resources/prow/k8s-infra-e2e-gcp-gcve-project-%03d" "${NR}")
  # shellcheck disable=SC2089
  ipPool="{\\\"addresses\\\":[\\\"${START}-${END}\\\"],\\\"gateway\\\":\\\"192.168.32.1\\\",\\\"prefix\\\":21}"

  boskos_data='{"ipPool":"'"${ipPool}"'","resourcePool":"'"${resourcePool}"'","folder":"'"${folder}"'"}'

  # acquire from "dirty" or "free" state
  ACQUIRED=1
  curl -s -X POST "${BOSKOS_HOST}/acquirebystate?names=${resourceName}&state=dirty&dest=busy&owner=$(whoami)" | grep -q "${resourceName}" \
    || curl -s -X POST "${BOSKOS_HOST}/acquirebystate?names=${resourceName}&state=free&dest=busy&owner=$(whoami)" | grep -q "${resourceName}" \
    || ( echo "Failed to acquire ${resourceName}" ; ACQUIRED=0)
  if [[ "${ACQUIRED}" -eq 0 ]]; then
    echo "Failed to acquire project ${resourceName}"
  fi

  # update resource
  echo "Updating resource ${resourceName} with following data: ${boskos_data}"
  # shellcheck disable=SC2089
  curl -s -X POST -d "${boskos_data}" "${BOSKOS_HOST}/update?name=${resourceName}&state=busy&owner=$(whoami)"
  
  # release as "dirty", janitor should bring it to "free"
  curl -s -X POST "${BOSKOS_HOST}/release?name=${resourceName}&dest=dirty&owner=$(whoami)"
  
  echo "Successfully updated project ${resourceName}"
}

for i in {1..40}; do
  initBoskosResourceUserData "${i}"
done
