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

readonly repo="gcr.io/cloud-provider-vsphere/csi/release"
readonly tag_filter="tags~^v\d+\.\d+\.\d+\$"
# List of repos under https://console.cloud.google.com/gcr/images/cloud-provider-vsphere/global/csi/release
readonly images=(
    driver
    driver-linux-amd64
    driver-windows-1809-amd64
    driver-windows-1903-amd64
    driver-windows-1909-amd64
    driver-windows-2004-amd64
    driver-windows-20h2-amd64
    driver-windows-ltsc2022-amd64
    syncer
)

for image in "${images[@]}"; do
    echo "- name: ${image}"
    echo "  dmap:"
    gcloud container images list-tags \
        "${repo}/$image" \
        --format="get(digest, tags)" \
        --sort-by="tags" \
        --filter="${tag_filter}" \
        | sed -e 's/\([^ ]*\)\t\(.*\)/    "\1": [ "\2" ]/'
done
