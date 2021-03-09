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

# List of repos under https://console.cloud.google.com/gcr/images/k8s-staging-sig-storage/GLOBAL
repos="
csi-attacher
csi-node-driver-registrar
csi-provisioner
csi-resizer
csi-snapshotter
csi-external-health-monitor-agent
csi-external-health-monitor-controller
hostpathplugin
livenessprobe
mock-driver
nfs-provisioner
snapshot-controller
snapshot-validation-webhook
local-volume-provisioner
"

for repo in $repos; do
    echo "- name: $repo"
    echo "  dmap:"
    gcloud container images list-tags gcr.io/k8s-staging-sig-storage/$repo --format='get(digest, tags)' --filter='tags~^v AND NOT tags~v2020 AND NOT tags~-rc' --sort-by=tags |
        sed -e 's/\([^ ]*\)\t\(.*\)/    "\1": [ "\2" ]/'
done

