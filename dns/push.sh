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

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

readonly SCRIPT_NAME="${0##*/}"
readonly TEST_ZONES_TRIES="12"

print_usage() {
  cat <<USAGE
usage: push.sh [options]
options:
  --confirm
            Confirmation the script will update the dns records and not run in
            dry-run mode
  --check-zone-script=FILE_PATH
            Path to python script which will be used to check if zones were
            updated and propagated properly
  -h, --help
            Show this help message and exit
  --logs-dir=<PATH>
            Where to place log files
            (detault: ".")
  --octodns-config=FILE_PATH
            Path to octodns config file
  --zone-configs=PATH
            Path to directory with dns zone config files

USAGE
}

# Parse script arguments
# Globals:
#   SCRIPT_NAME
# Example usage:
#   parse_args "$@"
parse_args() {
  local opts;
  opts=$(lib::gnu_getopt \
    --name "${SCRIPT_NAME}" \
    --longoptions "help,confirm,octodns-config:,check-zone-script:,zone-configs:,logs-dir:" \
    --options h \
    -- "$@"
  )

  if [[ $? != 0 ]] ; then
    print_usage
    exit 1
  fi

  # It is getopt's responsibility to make this safe
  eval set -- ${opts}

  while : ; do
    case "${1}" in
      --help|-h)            print_usage               ;;
      --confirm)            CONFIRMED=true            ;;
      --check-zone-script)  CHECK_ZONE_SCRIPT="${2}"; shift;;
      --logs-dir)           LOGS_DIR="${2}";          shift;;
      --octodns-config)     OCTODNS_CONFIG="${2}";    shift;;
      --zone-configs)       ZONE_CONFIGS="${2}";      shift;;
      --) shift;
        if [ $# -gt 0 ] ; then
            echo "Error: Extra arguments found: $*"
            print_usage
            exit 1
        fi
        break;;
      *) echo "Error: Invalid option ${1}"; exit 1;;
    esac
    shift
  done

  # set defaults
  if [[ -z "${CONFIRMED:-}" ]]; then
    CONFIRMED=false;
  fi
  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR=".";
  fi

  # validate options
  if [[ ! -f "${CHECK_ZONE_SCRIPT}" ]]; then
    echo -n "Error: '--check-zone-script' (${CHECK_ZONE_SCRIPT}) is not" >&2
    echo    " an existing file" >&2
    print_usage
    exit 1
  elif [[ ! -d "${LOGS_DIR}" ]]; then
    echo -n "Error: '--logs-dir' (${LOGS_DIR}) is not" >&2
    echo    " an existing directory" >&2
    print_usage
    exit 1
  elif [[ ! -w "${LOGS_DIR}" ]]; then
    echo "Error: '--logs-dir' (${LOGS_DIR}) is not writable" >&2
    print_usage
    exit 1
  elif [[ ! -f "${OCTODNS_CONFIG}" ]]; then
    echo -n "Error: '--octodns-config' (${OCTODNS_CONFIG}) is not" >&2
    echo    " an existing file" >&2
    print_usage
    exit 1
  elif [[ ! -d "${ZONE_CONFIGS}" ]]; then
    echo -n "Error: '--zone-configs' (${ZONE_CONFIGS}) is not an existing" >&2
    echo    " directory" >&2
    print_usage
    exit 1
  fi
}

main() {
  local tmp_path
  tmp_path="$(lib::create_tmp_path)" || return

  readonly TMP_PATH="${tmp_path}"
  readonly TMP_CONFIG_PATH="${tmp_path}/octodns-config.yaml"
  readonly TMP_ZONES_PATH="${tmp_path}/zones"
  readonly CANARY_LOG_FILE="${LOGS_DIR}/log.canary"
  readonly PROD_LOG_FILE="${LOGS_DIR}/log.prod"

  # Clean tmp dir when exit
  trap 'rm -rf "${TMP_PATH}"' EXIT

  lib::precook_zone_configs \
    "${ZONE_CONFIGS}" \
    "${TMP_ZONES_PATH}" \
    "${ALL_ZONES[@]}" || return

  lib::precook_octodns_config \
    "${OCTODNS_CONFIG}" \
    "${TMP_CONFIG_PATH}" \
    "${TMP_ZONES_PATH}" || return

  # Canary zones
    lib::dry_run \
      "${TMP_CONFIG_PATH}" \
      "${CANARY_LOG_FILE}" \
      "${CANARY_ZONES[@]}" || return

    # Push and test only if flag --confirm was passed
    if ${CONFIRMED}; then
      lib::push \
        "${TMP_CONFIG_PATH}" \
        "${CANARY_LOG_FILE}" \
        "${CANARY_ZONES[@]}" || return

      lib::test_zones \
        "${TMP_CONFIG_PATH}" \
        "${CHECK_ZONE_SCRIPT}" \
        "${CANARY_LOG_FILE}" \
        "${TEST_ZONES_TRIES}" \
        "${CANARY_ZONES[@]}" || return
    fi

  # Prod zones
    lib::dry_run \
      "${TMP_CONFIG_PATH}" \
      "${PROD_LOG_FILE}" \
      "${PROD_ZONES[@]}" || return

    # Push and test only if flag --confirm was passed
    if ${CONFIRMED}; then
      lib::push \
        "${TMP_CONFIG_PATH}" \
        "${PROD_LOG_FILE}" \
        "${PROD_ZONES[@]}" || return

      lib::test_zones \
        "${TMP_CONFIG_PATH}" \
        "${CHECK_ZONE_SCRIPT}" \
        "${PROD_LOG_FILE}" \
        "${TEST_ZONES_TRIES}" \
        "${PROD_ZONES[@]}" || return
    fi
}

lib::ensure_python3 || exit
parse_args "$@" || exit
main "$@"
