#!/usr/bin/env bash

# Copyright 2022 The Kubernetes Authors.
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

# runs $@ in dns image as you
# you must set DNS_IMAGE to the image to use
#
# It also expects working gcloud credentials

set -o errexit -o nounset -o pipefail

# cd to the repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "${REPO_ROOT}"

# settings:
DOCKER="${DOCKER:-docker}"
DNS_IMAGE="${DNS_IMAGE}"
if [[ -z "${DNS_IMAGE:-}" ]]; then
    >&2 echo "ERROR: DNS_IMAGE must be set!"
    exit 1
fi

"${DOCKER}" run -ti \
    --user "$(id -u)" \
    --volume ~/.config/gcloud:/.config/gcloud:ro \
    --volume "${REPO_ROOT}/dns":/octodns \
    --volume "/tmp:/tmp" \
    --workdir /octodns \
    "${DNS_IMAGE}" \
    "$@"
