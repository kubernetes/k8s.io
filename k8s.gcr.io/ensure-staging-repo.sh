#!/usr/bin/env bash
#
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

# This script is used to create a new "staging" repo in GCR.  Each sub-project
# that needs to publish container images should have their own staging repo.
#
# Each staging repo exists in its own GCP project, and is writable by a
# dedicated googlegroup.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 <repo>" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 coredns" > /dev/stderr
    echo > /dev/stderr
}

if [ $# != 1 ]; then
    usage
    exit 1
fi
if [ -z "$1" ]; then
    usage
    exit 2
fi

# The name of the sub-project being created, e.g. "coredns".
REPO="$1"

# The GCP project name.
PROJECT="k8s-staging-${REPO}"

# The group that can write to this staging repo.
WRITERS="k8s-infra-gcr-staging-${REPO}@googlegroups.com"

# Make the project, if needed
color 6 "Ensuring project exists: ${PROJECT}"
ensure_project "${PROJECT}"

color 6 "Configuring billing for ${PROJECT}"
ensure_billing "${PROJECT}"

# Enable container registry APIs
color 6 "Enabling the container registry API"
enable_api "${PROJECT}" containerregistry.googleapis.com

# Push an image to trigger the bucket to be created
color 6 "Ensuring the registry exists and is readable"
ensure_repo "${PROJECT}"

# Enable GCR admins
color 6 "Empowering GCR admins"
empower_gcr_admins "${PROJECT}"

# Enable repo writers
color 6 "Empowering ${WRITERS}"
empower_group "${PROJECT}" "${WRITERS}"

color 6 "Done"
