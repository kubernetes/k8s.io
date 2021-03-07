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
# It also requires working gcloud credentials
#
# $1: fqdn including final dot... ex "canary.k8s.io."

read -r -d '' USAGE <<- EOF
  Usage:
  $0 -c confdir -o octodns_config_path example.com.\t\t# Check a single zone
  $0 -c confdir -o octodns_config_path example.com. example.io.\t# Check a multiple zones
EOF

while getopts ":hc:o:" opt; do
  case ${opt} in
    c )
      TMPCFG="${OPTARG}"
      ;;
    o )
      OCTODNS_CONFIG="${OPTARG}"
      ;;
    h )
      echo -e "${USAGE}"
      exit 0
      ;;
    \? )
    echo -e "Invalid option.\n" >&2
    echo -e "${USAGE}" >&2
    exit 1
      ;;
  esac
done
shift $((OPTIND -1))

DOMAINS=("$@")

if [ -z "${TMPCFG}" ]; then
    echo -e "confdir must be specified" >&2
    echo -e "${USAGE}" >&2
    exit 2
fi
if [ ! -d "${TMPCFG}" ]; then
    echo -e "confdir must exist" >&2
    echo -e "${USAGE}" >&2
    exit 2
fi
if [ -z "${OCTODNS_CONFIG}" ]; then
    echo -e "octodns_config_path must be specified" >&2
    echo -e "${USAGE}" >&2
    exit 2
fi
if [ ! -f "${OCTODNS_CONFIG}" ]; then
    echo -e "octodns_config_path must exist" >&2
    echo -e "${USAGE}" >&2
    exit 2
fi

echo -n "Checking that the GCP dns servers for (${DOMAINS[*]})"
echo    " serve up everything in our octodns config"
./check-zone.py \
    --config-file="${OCTODNS_CONFIG}" \
    "${DOMAINS[@]/#/--zone=}"
RESULT=$?
if [ $RESULT != "0" ] ; then
    echo '***FAIL***'
    echo $RESULT
    exit $RESULT
else
    echo '***PASS***'
fi
