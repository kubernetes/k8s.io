#!/usr/bin/env bash

# Copyright 2024 The Kubernetes Authors.
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

readonly repo="us-central1-docker.pkg.dev/k8s-staging-images/secrets-store-sync"
# release candidates will be created for >=1.0.0 releases that we want published to the prod registry
readonly tag_filter="(tags~^v[0-9]+.[0-9]+.[0-9]+$) OR (tags~^v[0-9]+.[0-9]+.[0-9]+-rc.[0-9]+$ AND tags >= v1.0.0)"
readonly images=(
    controller
)

for image in "${images[@]}"; do
    echo "- name: ${image}"
    echo "  dmap:"
    gcloud container images list-tags \
        "${repo}/$image" \
        --format="get(digest, tags)" \
        --sort-by="tags" \
        --filter="${tag_filter}" | \
    sed -e 's/\([^ ]*\)\t\(.*\)/    "\1": [ "\2" ]/'
done
