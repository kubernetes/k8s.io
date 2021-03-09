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

repos="
driver
"

for repo in $repos; do
    echo "- name: $repo"
    echo "  dmap:"
    gcloud container images list-tags gcr.io/k8s-staging-csi-secrets-store/$repo --format='get(digest, tags)' --filter='tags~^v AND NOT tags~-amd64 AND NOT tags~v0.0.11' | sed -e 's/\([^ ]*\)\t\(.*\)/    "\1": [ "\2" ]/'
done
