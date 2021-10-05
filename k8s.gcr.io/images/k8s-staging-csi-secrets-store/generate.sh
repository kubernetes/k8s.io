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

set -o errexit
set -o nounset
set -o pipefail

readonly repo="gcr.io/k8s-staging-csi-secrets-store"
# release candidates will be created for >=1.0.0 releases that we want published to the prod registry
readonly tag_filter="(tags~^v[0-9]+.[0-9]+.[0-9]+$ AND NOT tags=v0.0.11) OR (tags~^v[0-9]+.[0-9]+.[0-9]+-rc.[0-9]+$ AND tags >= v1.0.0)"
readonly images=(
    driver
    driver-crds
)

for image in "${images[@]}"; do
    echo "- name: ${image}"
    echo "  dmap:"
    gcloud container images list-tags \
        "${repo}/$image" \
        --format="get(digest, tags)" \
        --sort-by="tags" \
        --filter="${tag_filter}" | \
    sed -e 's/\([^ ]*\)\t\(.*\)/    "\1": [ "\2" ]/' | \
    # fix for v0.0.22
    sed -e 's/981d4a484d156273a673b3d4e130ce6a7e09d25d8275b4acef78df697a67d7b2/1db2d1879a4ef656e3037a1d32be6bdb08cb10ea5800b6cca393361d6ac0330c/g'
done
