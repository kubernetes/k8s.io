#!/usr/bin/env bash

# Copyright 2021 The Kubernetes Authors.
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

# Diff the listings of two bucket paths

set -o errexit
set -o nounset
set -o pipefail

# common vars
script_name="$(basename "${BASH_SOURCE[0]%.*}")"
readonly script_name

# setup TMPDIR; if DEBUG, use consistent dir to cache, ls instead of rm on exit
function setup_tmpdir() {
  if [ "${DEBUG:-"false"}" == "true" ]; then
    TMPDIR="/tmp/${script_name}.$(echo "${@}" | sha1sum | cut -c1-7)"
    mkdir -p "${TMPDIR}"
    trap 'echo; find "${TMPDIR}" -type f -exec ls -l {} + | sed -e "s/^/# /"' EXIT
  else
    TMPDIR="$(mktemp -d "/tmp/${script_name}.XXX")"
    trap 'rm -rf "${TMPDIR}"' EXIT
  fi
  readonly TMPDIR
}

function iso_dt() {
  date +%Y-%m-%dT%H:%M:%S
}

function log() {
  echo "# $(iso_dt) - ${*}"
}

function main() {
  # usage
  if [ $# -lt 2 ]; then
    >&2 echo "usage: ${script_name} gs://old-bucket/path gs://new-bucket/path [exclude_regex]"
    exit 1
  fi

  local old="${1}"
  local new="${2}"
  local exclude_regex="${3:-'^$'}"

  # ensure buckets are of form gs://foo
  for var in old new; do
    v=${!var}; if [ "${v:0:5}" != "gs://" ]; then declare ${var}="gs://${v}"; fi
  done

  # get into a working directory
  setup_tmpdir "${old}" "${new}"
  pushd "${TMPDIR}" >/dev/null

  # get listings, sort for benefit of comm and diff below
  for var in old new; do
    f="${var}.raw.txt"
    v="${!var}"
    if ! [ -f "${f}" ]; then
      log "listing ${v}"
      gsutil ls "${v}" | sed -e "s|${v%%\*}||" | sort > "${f}"
    fi
  done

  log "filtering to exclude lines matching '${exclude_regex}'"
  for var in old new; do
    <"${var}.raw.txt" grep -E -v "${exclude_regex}" >"${var}.txt"
  done

  # NB: either is computed at end with fewer lines for speed
  log "computing lines in common, only old, only new, and either"
  comm -12 {old,new}.txt >common.txt
  comm -23 {old,new}.txt >only.old.txt
  comm -13 {old,new}.txt >only.new.txt
  cat {common,only.{old,new}}.txt | sort >either.txt

  log "computing counts of lines in common, only old, only new, and either"
  for var in either common only_old only_new; do
    v=$(printf "%d" "$(<${var/_/.}.txt wc -l)")
    declare num_${var}="${v}"
  done

  # setup max padding for summarize below
  len="${#old}"
  if [ "${#old}" -lt "${#new}" ]; then len="${#new}"; fi
  len=$((len + 9))

  # setup max count for summarize below
  total=${num_either:?}

  function summarize() {
    local var="num_${1}" description="${2}"
    local v pct
    v="${!var}"
    pct="$(bc -l <<< "100*${v}/${total}")"
    printf "#   %-${len}s : %6d (%5.1f%%)\n" "${description}" "${v}" "${pct}"
  }

  echo
  (
    echo "# date: $(iso_dt)"
    echo "# old: ${old}"
    echo "# new: ${new}"
    echo "# exclude_regex: ${exclude_regex}"
    echo "# summary:"
    summarize "either"   "total  (in either)"
    summarize "common"   "common (in both)"
    summarize "only_old" "only in ${old}"
    summarize "only_new" "only in ${new}"
  ) | tee summary.txt
}

main "$@"
