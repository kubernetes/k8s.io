#!/usr/bin/env bash
#
# Copyright 2020 The Kubernetes Authors.
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

# This is a library of functions used to manage DNS stuff.

readonly PROD_ZONES=(
    k8s.io.
    kubernetes.io.
    x-k8s.io.
    k8s-e2e.com.
)

readonly CANARY_ZONES=("${PROD_ZONES[@]/#/canary.}")

export ALL_ZONES=(
    "${CANARY_ZONES[@]}"
    "${PROD_ZONES[@]}"
)

# Function which checks if GNU getopt is present (MacOS comes with different
# version of getops by default). If not present it exits with code 6, and if 
# present, calls it with all provided to function parameters
# Arguments:
#   $1, ... - the same arguments as GNU getopt accepts
# Exit codes:
#   1-5:  GNU getopt exit codes (read more in "man getopt")
#   6:    GNU getopt not found
lib::gnu_getopt() {
  if ! [[ "$(getopt --version)" =~ ^getopt\ from\ util-linux\ 2\.(.*)$ ]]; then
    echo    "Failed to find GNU getopt v2. If you are on Mac:" >&2
    echo    "  brew install gnu-getopt" >&2
    echo    "" >&2
    echo    "  # bash" >&2
    echo -n "  echo 'export PATH=\"/usr/local/opt/gnu-getopt/bin:\$PATH\"'" >&2
    echo    ' >> ~/.bash_profile' >&2
    echo    "" >&2
    echo    "  # zsh" >&2
    echo -n "  echo 'export PATH=\"/usr/local/opt/gnu-getopt/bin:\$PATH\"'" >&2
    echo    ' >> ~/.zshrc' >&2
    exit 6
  fi

  getopt "$@"
}

# Function which checks if octodns-sync is present and if not, returnes with
# code 1. If octodns-sync is present it calls it with all provided to function
# parameters
# Arguments:
#   $1, ... - the same arguments as octodns-sync accepts
# Example usage:
#   lib::octodns_sync --config-file=./octodns-config.yaml k8s.io.
#   lib::octodns_sync --config-file=./octodns-config.yaml --doit k8s.io.
#   lib::octodns_sync --config-file=./octodns-config.yaml --doit \
#     canary.k8s.io. canary.kubernetes.io. canary.k8s-e2e.com. canary.x-k8s.io.
lib::octodns_sync() {
  if ! octodns-sync --version > /dev/null 2>&1; then
    echo "Error: Failed to find octodns-sync" >&2
    return 1
  fi

  octodns-sync \
    --log-stream-stdout \
    --debug \
    "$@"
}

# As some parts of this scripts relies on the returned from function codes
# it was tricky to implement this function similarrily as 'lib::gnu_getopt'
# (which is the recomended way). To ensure the python3 is present on the system
# this function was implemented instead
# Arguments:
#   None
# Example usage:
#   lib::ensure_python3
lib::ensure_python3() {
  local regex='^Python\ 3\.(.*)$'

  if command -v python > /dev/null 2>&1 \
    && [[ "$(python --version 2>&1)" =~ ${regex} ]]
  then
    PYTHON3="python"
  elif command -v python3 > /dev/null 2>&1 \
    && [[ "$(python3 --version 2>&1)" =~ ${regex} ]]
  then
    PYTHON3="python3"
  else
    echo -n "Failed to find python 3 as python or python3" >&2
    echo    " If you are on Mac: brew install python" >&2
    return 1
  fi

  export PYTHON3
}

# Helper function to create temporary directory for octodns config file
# with subdirectory for zone config files
# Arguments:
#   None
# Outputs:
#   Writes created temporary location to stdout
# Example Usage:
#   lib::create_tmp_path
lib::create_tmp_path() {
    local tmp_path;
    tmp_path="$(mktemp -d /tmp/octodns.XXXXXX)" || return
    mkdir "${tmp_path}/zones" || return
    echo "${tmp_path}"
}

# Some zones have multiple files that need to be joined together
# Arguments:
#   $1:       path where zone configs are storred
#   $2:       path where processed zone configs will be storred
#   $3, ...:  zones to precook
# Example Usage:
#   lib::precook_zone_configs ./zone-configs /tmp/octodns k8s.io.
#   lib::precook_zone_configs ./zone-configs /tmp/octodns k8s.io. \
#     kubernetes.io. k8s-e2e.com. x-k8s.io.
lib::precook_zone_configs() {
  local fn_desc="lib::precook_zone_configs(configs_path, tmp_path, zone...)"
  if [[ $# -lt 3 ]]; then
    echo "${fn_desc}: function requires at least 3 arguments" >&2
    return 1
  elif [[ ! -d "${1}" ]]; then
    echo "${fn_desc}: 'configs_path' (${1}) is not an existing directory" >&2
    return 1
  elif [[ ! -d "${2}" ]]; then
    echo "${fn_desc}: 'tmp_path' (${2}) is not an existing directory" >&2
    return 1
  fi

  local configs_path="$1"; shift
  local tmp_path="$1"; shift
  local zones=("$@")

  echo "Using ${tmp_path} for cooked config files"

  for zone in "${zones[@]}"; do
    # Every zone should have 1 file $zone.yaml or N files $zone._*.yaml.
    # $zone already ends in a period.
    cat "${configs_path}/${zone}"yaml "${configs_path}/${zone}"_*.yaml \
      > "${tmp_path}/${zone}yaml" 2>/dev/null

    if [ ! -s "${tmp_path}/${zone}yaml" ]; then
      echo -n "${fn_desc}: ${tmp_path}/${zone}yaml appears to be empty" >&2
      echo    " after pre-processing!" >&2
      return 1
    fi
  done
}

# As octodns-sync expects config file with provided path to directory with dns
# zones configurations, and we need to preprocess them before this function
# is responsible for preparing config file with proper path set
# Arguments:
#   $1: file path where source octodns config file exist
#   $2: file path where processed octodns config file should be placed
#       parrent directory has to exist
#   $3: path where zone configs are storred
# Example Usage:
#   lib::precook_octodns_config ./octodns-config.yaml /tmp/foo ./zone-configs
lib::precook_octodns_config() {
  local fn_desc="lib::precook_octodns_config(source, destination, zones_path)"
  if [[ $# != 3 ]]; then
    echo "${fn_desc}: function requires 3 arguments" >&2
    return 1
  elif [[ ! -f "${1}" ]]; then
    echo "${fn_desc}: 'source' (${1}) is not an existing file" >&2
    return 1
  elif [[ -f "${2}" ]]; then
    echo "${fn_desc}: 'destination' file (${2}) already exist" >&2
    return 1
  elif [[ -d "${2}" ]]; then
    echo "${fn_desc}: 'destination' (${2}) can't be a directory" >&2
    return 1
  elif [[ ! -d $(dirname "${2}") ]]; then
    echo -n "${fn_desc}: 'destination' parrent directory" >&2
    echo    " ($(dirname "${2}")) doesn't exist" >&2
    return 1
  elif [[ ! -d "${3}" ]]; then
    echo "${fn_desc}: 'zones_path' (${3}) is not an existing directory" >&2
    return 1
  fi

  local source="${1}";
  local destination="${2}";
  local zones_path="${3}";

  sed "s|directory:.*$|directory: ${zones_path}|" \
    < "${source}" \
    > "${destination}"
}

# Dry run of dns updates for provided zones
# Arguments:
#   $1:       octodns config file path
#   $2:       path to file where the logs will be stored
#   $3, ...:  dns zones to dry-run
# Example Usage:
#   lib::dry_run ./octodns-config.yaml ./logs.prod k8s.io.
#   lib::dry_run ./octodns-config.yaml ./logs.canary .k8s.io. canary.x-k8s.io.
#   lib::dry_run ./octodns-config.yaml ./logs.prod k8s.io. kubernetes.io. \
#     k8s-e2e.com. x-k8s.io.
lib::dry_run() {
  local fn_desc="lib::dry_run(config_file, log_file, zone...)"

  if [[ $# -lt 3 ]]; then
    echo "${fn_desc}: function requires at least 3 arguments" >&2
    return 1
  elif [[ ! -f "${1}" ]]; then
    echo "${fn_desc}: 'config_file' (${1}) is not an extisting file" >&2
    return 1
  elif [[ ! -f "${2}" ]] && [[ ! -d "$(dirname "${2}")" ]]; then
    echo "${fn_desc}: 'log_file' (${2}) and it's parrent directory \
      ($(dirname "${2}")) doesn't exist" >&2
    return 1
  fi

  local config_file="$1"; shift
  local log_file="$1"; shift
  local zones=("$@")

  echo "Dry-run to zones: ${zones[*]}"

  if ! lib::octodns_sync \
    --config-file="${config_file}" \
    "${zones[@]}" \
    > "${log_file}" 2>&1
  then
    echo "Dry-run FAILED, halting; log follows:" >&2
    echo "=========================================" >&2
    cat "${log_file}" >&2
    return 3
  fi
}

# Function which will update the DNS records (not a dry-run)
# Arguments:
#   $1:       octodns config file path
#   $2:       path to file where the logs will be stored
#   $3, ...:  dns zones to dry-run
# Example Usage:
#   lib::push ./octodns-config.yaml ./logs.prod k8s.io.
#   lib::push ./octodns-config.yaml ./logs.canary .k8s.io. canary.x-k8s.io.
#   lib::push ./octodns-config.yaml ./logs.prod k8s.io. kubernetes.io. \
#     k8s-e2e.com. x-k8s.io.
lib::push() {
  local fn_desc="lib::push(config_file, log_file, zone...)"

  if [[ $# -lt 3 ]]; then
    echo "${fn_desc}: function requires at least 3 arguments" >&2
    return 1
  elif [[ ! -f "${1}" ]]; then
    echo "${fn_desc}: 'config_file' (${1}) is not an extisting file" >&2
    return 1
  elif [[ ! -f "${2}" ]] && [[ ! -d "$(dirname "${2}")" ]]; then
    echo -n "${fn_desc}: 'log_file' (${2}) and it's parrent directory"
    echo    " ($(dirname "${2}")) doesn't exist" >&2
    return 1
  fi

  local config_file="$1"; shift
  local log_file="$1"; shift
  local zones=("$@")

  echo "Push to zones: ${zones[*]}"

  if ! lib::octodns_sync \
    --config-file="${config_file}" \
    --doit \
    "${zones[@]}" \
    >> "${log_file}" 2>&1
  then
    echo "Push FAILED, halting; log follows:" >&2
    echo "=========================================" >&2
    cat "${log_file}" >&2
    return 3
  fi
}

# Function to check if dns zone was updated and propagated properly
# Globals:
#   PYTHON3
# Arguments:
#   $1: path to python script which will do actuall checking
#   $2: path to octodns config file
#   #3: dns zone which should be checked
# Example Usage:
#   lib::check_zone ./check-zone.py ./octodns-config.yaml k8s.io.
lib::check_zone() {
  local fn_desc="lib::check_zone(check_zone_script, config_file, zone)"

  if [[ $# != 3 ]]; then
    echo "${fn_desc}: function requires 3 arguments" >&2
    return 1
  elif [[ ! -f "${1}" ]]; then
    echo "${fn_desc}: 'check_zone_script' (${1}) is not an existing file" >&2
    return 1
  elif [[ ! -f "${2}" ]]; then
    echo "${fn_desc}: 'config_file' (${2}) is not an existing file" >&2
    return 1
  elif [[ -z "${3}" ]]; then
    echo "${fn_desc}: 'zone' (${3}) can't be empty" >&2
    return 1
  fi

  local check_zone_script="${1}"
  local config_file="${2}"
  local zone="${3}"

  ${PYTHON3} "${check_zone_script}" \
    --config-file "${config_file}" \
    --zone "${zone}"
}

# Function to test dns zones with retry logic
# Arguments:
#   $1:       path to octodns config file
#   $2:       path to python script which will do actuall checking
#   $3:       path to file where the logs should be stored
#   $4:       how many times to test if updates were propagated properly
#             before assume the update failed
#   $5. ...:  dns zones to test
# Example usage:
#   lib::test_zones ./octodns-config.yaml ./check-zone.py log.prod 12 k8s.io.
#   lib::test_zones ./octodns-config.yaml ./check-zone.py log.canary 12 \
#     canary.k8s.io. kubernetes.io. k8s-e2e.com. x-k8s.io.
lib::test_zones() {
  local fn_desc="lib::test_zones(config_file, check_zone_script, log_file, \
    tries, zone...)"

  if [[ $# -lt 5 ]]; then
    echo "${fn_desc}: function requires at least 5 arguments" >&2
    return 1
  elif [[ ! -f "${1}" ]]; then
    echo "${fn_desc}: 'config_file' (${1}) is not an existing file" >&2
    return 1
  elif [[ ! -f "${2}" ]]; then
    echo "${fn_desc}: 'check_zone_script' (${2}) is not an existing file" >&2
    return 1
  elif [[ ! -f "${3}" ]] && [[ ! -d "$(dirname "${3}")" ]]; then
    echo "${fn_desc}: 'log_file' (${3}) and it's parrent directory \
      ($(dirname "${3}")) doesn't exist" >&2
    return 1
  elif [[ ! "${4}" =~ ^[0-9]+$ ]]; then
    echo "${fn_desc}: 'tries' (${4}) is not a number" >&2
    return 1
  fi

  local config_file="${1}"; shift
  local check_zone_script="${1}"; shift
  local log_file="${1}"; shift
  local tries="${1}"; shift
  local zones=("$@")

  for zone in "${zones[@]}"; do
    echo "Testing zone: ${zone}"

    for i in $(seq 1 "${tries}"); do
      if lib::check_zone "${check_zone_script}" "${config_file}" "${zone}" \
        >> "${log_file}" 2>&1
      then
        break
      fi
      if [ "${i}" != "${tries}" ]; then
        echo -n "  test failed, might be propagation delay, will retry..." >&2
        echo    " (${i}/${tries})" >&2
        sleep 10
      else
        echo "Test FAILED, halting; log follows:" >&2
        echo "==================================" >&2
        cat "${log_file}" >&2
        exit 2
      fi
    done

    echo "Zone: ${zone} SUCCEEDED"
  done
}
