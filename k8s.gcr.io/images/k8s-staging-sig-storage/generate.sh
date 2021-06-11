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
readonly tag_filter="tags~^v AND NOT tags~v2020 AND NOT tags~-rc"
# List of repos under https://console.cloud.google.com/gcr/images/k8s-staging-sig-storage/GLOBAL
readonly images=(
    csi-attacher
    csi-external-health-monitor-agent
    csi-external-health-monitor-controller
    csi-node-driver-registrar
    csi-provisioner
    csi-resizer
    csi-snapshotter
    hostpathplugin
    iscsiplugin
    livenessprobe
    local-volume-provisioner
    mock-driver
    nfs-provisioner
    nfs-subdir-external-provisioner
    # TODO: nfsplugin?
    snapshot-controller
    snapshot-validation-webhook
    # TODO: validation-webhook?
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