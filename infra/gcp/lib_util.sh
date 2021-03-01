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

# Generic utility functions
#
# This is intended to be very general-purpose and "low-level".  Higher-level
# policy does not belong here.
#
# This MUST NOT be used directly. Source it via lib.sh instead.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "${script_dir}/../.." && pwd)

function _color() {
    tput setf "$1" || true
}

function _nocolor() {
    tput sgr0 || true
}

# Print the arguments in a given color
# $1: The color code (numeric, see `tput setf`)
# $2+: The things to print
function color() {
    _color "$1"
    shift
    echo "$*$(_nocolor)"
}

# ensure_gnu_sed
# Determines which sed binary is gnu-sed on linux/darwin
#
# Sets:
#  SED: The name of the gnu-sed binary
#
function ensure_gnu_sed() {
    sed_help="$(LANG=C sed --help 2>&1 || true)"
    if echo "${sed_help}" | grep -q "GNU\|BusyBox"; then
        SED="sed"
    elif command -v gsed &>/dev/null; then
        SED="gsed"
    else
        >&2 echo "Failed to find GNU sed as sed or gsed. If you are on Mac: brew install gnu-sed"
        return 1
    fi
    export SED
}

function verify_prereqs() {
    # indent relies on sed -u which isn't available in macOS's sed
    if ! ensure_gnu_sed; then
        exit 1
    fi
    # ensure-e2e-projects, ensure-main-project, ensure-namespaces rely on this
    # we're not checking for a specific version; 1.6 has not yet made it to distributions
    if ! command -v jq &>/dev/null; then
        >&2 echo "jq not found. Please install: https://stedolan.github.io/jq/download/"
        exit 1
    fi
    # generate-role-yaml relies on this
    # opting for https://kislyuk.github.io/yq/ over https://github.com/mikefarah/yq due to
    # parity with jq, but may be worth reconsidering
    if ! command -v yq &>/dev/null; then
        >&2 echo "yq not found. Please install, e.g. pip3 install -r ${repo_root}/requirements.txt"
        exit 1
    fi
}

if ! verify_prereqs; then
  exit 1
fi

# Indent each line of stdin.
# example: <command> | indent
function indent() {
    ${SED} -u 's/^/  /'
}

# Join things with separator
# Arguments:
#   $1:  Separator (has to be single character)
#   $2+: The things to join
# Example usage:
#   join_by , foo bar baz
function join_by() {
  if [ $# -lt 2 ] || [ -z "${1}" ] || [ -z "${2}" ]; then
      echo "join_by(separator, string...) requires at least 2 arguments" >&2
      return 1
  fi

  local IFS="${1}"; shift
  # Using $* and not $@ is not a mistake, as $* returns string and respect IFS
  # and $@ returns array which doesn't respect IFS
  echo "$*"
}
