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

# This script is used to ensure Release Engineering subproject owners have the
# appropriate access to SIG Release prod GCP projects.
#
# Projects:
# - k8s-releng-prod - Stores KMS objects which other release projects will
#                       be granted permission to decrypt e.g., GITHUB_TOKEN

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 [project...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all release projects" > /dev/stderr
    echo "  $0 k8s-releng-prod # just do one" > /dev/stderr
    echo > /dev/stderr
}

# NB: Please keep this sorted.
PROJECTS=(
    k8s-releng-prod
)

if [ $# = 0 ]; then
    # default to all release projects
    set -- "${PROJECTS[@]}"
fi

for PROJECT; do
    color 3 "Configuring: ${PROJECT}"

    # Make the project, if needed
    color 6 "Ensuring project exists: ${PROJECT}"
    ensure_project "${PROJECT}"

    # Enable admins to use the UI
    color 6 "Empowering ${RELEASE_ADMINS} as project viewers"
    empower_group_as_viewer "${PROJECT}" "${RELEASE_ADMINS}"

    # Enable KMS APIs
    color 6 "Enabling the KMS API"
    ensure_only_services "${PROJECT}" cloudkms.googleapis.com

    # Let project admins use KMS.
    color 6 "Empowering ${RELEASE_ADMINS} as KMS admins"
    empower_group_for_kms "${PROJECT}" "${RELEASE_ADMINS}"

    color 6 "Done"
done
