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

readonly repo="gcr.io/k8s-staging-sig-storage"
readonly tag_filter="tags~^v\d+\.\d+\.\d+\$"
readonly win_hcp_tag_filter="tags~^v\d+\.\d+\.\d+[a-z-]*$" # only for image supporting windows host process deployment
# List of repos under https://console.cloud.google.com/gcr/images/k8s-staging-sig-storage/GLOBAL
readonly images=(
    csi-attacher
    csi-external-health-monitor-agent
    csi-external-health-monitor-controller
    csi-node-driver-registrar
    csi-provisioner
    csi-resizer
    csi-snapshot-metadata
    csi-snapshotter
    hello-populator
    hostpathplugin
    iscsiplugin
    livenessprobe
    local-volume-provisioner
    local-volume-node-cleanup
    mock-driver
    nfs-provisioner
    nfs-subdir-external-provisioner
    nfsplugin
    objectstorage-controller
    objectstorage-sidecar
    smbplugin
    snapshot-controller
    snapshot-validation-webhook
    volume-data-source-validator
)

for image in "${images[@]}"; do
    echo "- name: ${image}"
    echo "  dmap:"
    filter="${tag_filter}"
    if [[ "${image}" == "smbplugin" ]]; then
        filter="${win_hcp_tag_filter}"
    fi
    gcloud container images list-tags \
        "${repo}/$image" \
        --format="get(digest, tags)" \
        --sort-by="tags" \
        --filter="${filter}" \
        | grep --invert-match ';' \
        | sed -e 's/\([^ ]*\)\t\(.*\)/    "\1": [ "\2" ]/'
    # note: grep invert ';': for images with multiple tags, listed tags are separated by semicolons
    # this script doesn't handle multi-tagged images, so ignore them to avoid image promotion errors
done
