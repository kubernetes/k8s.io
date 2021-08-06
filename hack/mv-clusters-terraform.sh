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

# Script to generate commits to:
# - mv infra/gcp/clusters to infra/gcp/terraform
# - mv terraform/projects/{foo} to terraform/{foo}
# - mv terraform/{foo}/{cluster}/*.tf to terraform/{foo}/*.tf
# - update all scripts and docs in-repo accordingly


set -o errexit
set -o nounset
set -o pipefail
set -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd )"

pushd "${REPO_ROOT}"

if ! [ -d infra/gcp/terraform ]; then
  pushd infra/gcp
  git mv clusters terraform
  pushd terraform
  git mv projects/* .
  git mv k8s-infra-prow-build/prow-build/*.tf                 k8s-infra-prow-build/
  git mv k8s-infra-prow-build-trusted/prow-build-trusted/*.tf k8s-infra-prow-build-trusted/
  git mv kubernetes-public/aaa/*.tf kubernetes-public/
  popd
  popd
  git ci -m "mv infra/gcp/clusters infra/gcp/terraform"
fi

for f in $(rg -l infra/gcp/clusters | grep -v hack/mv-clusters); do
  sed \
    -i.bak \
    -e 's|infra/gcp/clusters|infra/gcp/terraform|g' \
    -e 's|terraform/projects/\([^/]*\)/|terraform/\1|g' \
    "$f"
  rm "$f.bak"
done

for f in $(git status --porcelain | grep '^[ M][ M] ' | awk '{print $2}'); do
  git add "$f"
done

git ci -m "update scripts to follow infra/gcp/terraform mv"
