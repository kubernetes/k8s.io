#!/usr/bin/env bash

# Copyright 2026 The Kubernetes Authors.
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

readonly repo="gcr.io/k8s-staging-cloud-provider-gcp"
readonly tag_filter="tags~^v\d+\.\d+\.\d+\$"

# Pick up images from current image file. This should be bootstrapped
# from https://console.cloud.google.com/gcr/images/k8s-staging-cloud-provider-gcp/GLOBAL.

num_images=$(yq '. | length' images.yaml)
rm -f _new_images.yaml
for ((i=0; i<num_images; i++)); do
  image=$(yq ".[$i].name" images.yaml)
  existing="_${image}_existing"

  yq ".[$i]" images.yaml \
    | grep sha256 \
    | while read -r _ tag; do echo "$tag"; done \
    > "$existing"
  
  {
    echo "- name: ${image}"
    echo "  dmap:"
    # Copy over existing lines.
    yq ".[$i]" images.yaml | grep sha256 \
      | while read -r digest tag; do
          # The digest contains a colon already
          echo "    ${digest} ${tag}"
        done
  } >> _new_images.yaml

  # Find any new image tags not already in the file.
  # For older tags, the digests in the registry may not match
  # what have already been promoted.
  gcloud container images list-tags \
        "${repo}/$image" \
        --format="get(digest, tags)" \
        --sort-by="tags" \
        --filter="${tag_filter}" \
        | while read -r digest tag; do
    if echo "$tag" | grep -q v999; then
      # Skip experimental releases (v999.x)
      continue
    fi
    if ! grep -Fq "$tag" "$existing"; then
      echo "    \"${digest}\": [\"${tag}\"]" >> _new_images.yaml
    fi
  done
  rm -f "$existing"
done
mv _new_images.yaml images.yaml
