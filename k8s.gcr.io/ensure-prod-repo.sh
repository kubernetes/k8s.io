#!/bin/sh
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

# This script creates & configures the "real" serving repo in GCR.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
source "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0" > /dev/stderr
    echo > /dev/stderr
}

if [ $# != 0 ]; then
    usage
    exit 1
fi

# The GCP project names.
PROD_PROJECT="k8s-gcr-prod"
TRASH_PROJECT="k8s-gcr-graveyard"

# Make the projects, if needed
color 6 "Ensuring prod project exists"
ensure_project "${PROD_PROJECT}"
color 6 "Ensuring graveyard project exists"
ensure_project "${TRASH_PROJECT}"

color 6 "Configuring billing for ${PROD_PROJECT}"
ensure_billing "${PROD_PROJECT}"
color 6 "Configuring billing for ${TRASH_PROJECT}"
ensure_billing "${TRASH_PROJECT}"

# Enable container registry APIs
color 6 "Enabling the container registry API"
enable_api "${PROD_PROJECT}" containerregistry.googleapis.com
enable_api "${TRASH_PROJECT}" containerregistry.googleapis.com

color 6 "Enabling the container analysis API"
enable_api "${PROD_PROJECT}" containeranalysis.googleapis.com

# Push an image to trigger the bucket to be created
color 6 "Ensuring the registry exists and is readable"
ensure_repo "${PROD_PROJECT}"
ensure_repo "${TRASH_PROJECT}"

# Enable GCR admins
color 6 "Empowering GCR admins"
empower_gcr_admins "${PROD_PROJECT}"
empower_gcr_admins "${TRASH_PROJECT}"

# Enable the promoter bot
color 6 "Empowering image promoter"
empower_promoter "${PROD_PROJECT}"
empower_promoter "${TRASH_PROJECT}"

# Set lifecycle policies.
color 6 "Setting lifecycle policy on ${PROD_PROJECT}"
ensure_prod_lifecycle "${PROD_PROJECT}"
color 6 "Setting lifecycle policy on ${TRASH_PROJECT}"
ensure_staging_lifecycle "${TRASH_PROJECT}"

color 6 "Done"
