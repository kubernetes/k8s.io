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
    sed -e 's/981d4a484d156273a673b3d4e130ce6a7e09d25d8275b4acef78df697a67d7b2/1db2d1879a4ef656e3037a1d32be6bdb08cb10ea5800b6cca393361d6ac0330c/g' | \
    # v1.0.0-rc.1 was rebuilt for base image CVE fix. But since the prod tag is immutable we need to use the old one for the RC
    sed -e 's/80b95ffe1d3f6a53228811163f0cb19ce3f16dbacc667253ac1457d2248415ff/551b115899673133513093245b009d41bb2f520f6ba758c99ef020e23366f810/g' | \
    sed -e 's/4db5d24dbe7610199d27f0791a1b238bcb06de80305755a0d558c358c5467327/6a7f1eeb51fcd396f628821ed9b06d86723e91dc83c0e77e1c5185ac9bc52398/g' | \
    # v1.0.0 was rebuilt for base image CVE fix. But since the prod tag is immutable we need to use the old one for the RC
    sed -e 's/9328d01faac9c48858dd56c10dbeffaa55ea4e4c51c7f3316822e93f9f63476a/6a5f9f3961e4c9827ba2e86a4918fce04150fbc979759ee540479f395253db5e/g' | \
    sed -e 's/f52bfe35d98d3ad4b81c5e8a8b15bc9269cdb17b312376fdb75559108454423d/04dc2bf839bc86503943ab3303fd3ddc60961f502eec64ed729611979cb9fe51/g'
done
