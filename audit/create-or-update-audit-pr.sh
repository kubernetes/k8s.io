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

# Run the audit script and create or update a PR containing any changes

# NOTE: This is intended to run on k8s-infra-prow-build-trusted as
#       k8s-infra-gcp-auditor@kubernetes-public.iam.gserviceaccount.com

# TODO: Running locally is a work in progress, there are assumptions
#       made about the environment in which this runs:
#       - must have certain env vars present
#       - must have kubernetes/test-infra in a certain location
#       - must be able to build kubernetes/test-infra
#       - must have gcloud already authenticated as someone who has the
#         custom org role "audit.viewer"

set -o errexit
set -o nounset
set -o pipefail

GH_USER=cncf-ci
GH_NAME="CNCF CI Bot"
GH_EMAIL="cncf-ci@ii.coop"
GH_TOKEN=$(cat /etc/github-token/token)
FORK_GH_REPO=k8s.io
FORK_GH_BRANCH=autoaudit-${PROW_INSTANCE_NAME:-prow}
FORK_URI="https://github.com/${GH_USER}/${FORK_GH_REPO}"

if [ -z "${GH_TOKEN}" ]; then
  >&2 echo "ERROR: GH_TOKEN is empty"
  exit 1
fi

echo "Ensure git configured" >&2
git config user.name "${GH_NAME}"
git config user.email "${GH_EMAIL}"

echo "Ensure gcloud creds are working" >&2
gcloud config list

echo "Ensure git creds are working" >&2
git config --list

echo "Running Audit Script to dump GCP configuration to yaml" >&2
pushd ./audit
bash ./audit-gcp.sh
popd

echo "Determining whether there are changes to push" >&2
git add --all audit
git commit -m "audit: update as of $(date +%Y-%m-%d)"
if git remote get-url fork >/dev/null; then
  git remote set-url fork "${FORK_URI}"
else
  git remote add fork "${FORK_URI}"
fi
if git fetch fork "${FORK_GH_BRANCH}"; then
    if git diff --quiet HEAD "fork/${FORK_GH_BRANCH}" -- audit; then
    echo "No new changes to push, exiting early..." >&2
    exit
    fi
fi

prcreator=pr-creator
if ! command -v "${prcreator}" &>/dev/null; then
    echo "Generating pr-creator binary from k/test-infra/robots" >&2
    pushd ../../kubernetes/test-infra
    go build -o /workspace/pr-creator robots/pr-creator/main.go
    prcreator=/workspace/pr-creator
    popd
fi

echo "Pushing commit to github.com/${GH_USER}/${FORK_GH_REPO}..." >&2

git push -f "https://${GH_USER}:${GH_TOKEN}@github.com/${GH_USER}/${FORK_GH_REPO}" "HEAD:${FORK_GH_BRANCH}" 2>/dev/null

echo "Creating or updating PR to merge ${GH_USER}:${FORK_GH_BRANCH} into kubernetes:main..." >&2
"${prcreator}" \
    --github-token-path=/etc/github-token/token \
    --org=kubernetes --repo=k8s.io --branch=main \
    --source="${GH_USER}:${FORK_GH_BRANCH}" \
    --head-branch="${FORK_GH_BRANCH}" \
    --title="audit: update as of $(date +%Y-%m-%d)" \
    --body="Audit Updates wg-k8s-infra" \
    --confirm
