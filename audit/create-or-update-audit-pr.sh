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
set -x

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)

#
# config (overridable)
#

# paths used to build/install pr-creator if not present in PATH
readonly TEST_INFRA_DIR="${TEST_INFRA_DIR:-${REPO_ROOT}/../test-infra}"
readonly AUDIT_BIN_DIR="${AUDIT_BIN_DIR:-${REPO_ROOT}/tmp/bin}"

# git name/e-mail that will commit changes
readonly GIT_NAME=${GIT_NAME:-"Kubernetes Prow Robot"}
readonly GIT_EMAIL=${GIT_EMAIL:-"k8s-infra-ci-robot@kubernetes.io"}

# github user that will push and PR changes. They must have permissions to:
# - push FORK_BRANCH to ${fork_public_url}
# - open and update PRs made from ${fork_public_url}
#
# NB: since pr-creator requires a token path, this script does not support
#     automatically picking up GITHUB_TOKEN from en
readonly GITHUB_USER=${GITHUB_USER:-"k8s-infra-ci-robot"}
readonly GITHUB_TOKEN_PATH=${GITHUB_TOKEN_PATH:-"/etc/github-token/token"}
GITHUB_TOKEN=$(cat "${GITHUB_TOKEN_PATH}")
readonly GITHUB_TOKEN

# github repo and branch where changes are pushed and PR'ed from
readonly FORK_GITHUB_USER=${FORK_GITHUB_USER:-${GITHUB_USER}}
readonly FORK_GITHUB_REPO=${FORK_GITHUB_REPO:-"k8s.io"}
readonly FORK_BRANCH=${FORK_BRANCH:-"autoaudit-${PROW_INSTANCE_NAME:-"prow"}"}
readonly FORK_REMOTE_NAME=${FORK_REMOTE_NAME:-"fork"}

# github repo where changes are PR'ed to
readonly BASE_GITHUB_USER=${BASE_GITHUB_USER:-"kubernetes"}
readonly BASE_GITHUB_REPO=${BASE_GITHUB_REPO:-"k8s.io"}
# TODO: this could be excluded since pr-creator supports default branch
readonly BASE_BRANCH=${BASE_BRANCH:-"main"}

#
# config (computed)
#

readonly audit_dir="./audit"
readonly fork_public_url="https://github.com/${FORK_GITHUB_USER}/${FORK_GITHUB_REPO}"
readonly fork_private_url="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${FORK_GITHUB_USER}/${FORK_GITHUB_REPO}"

#
# functions
#

function cleanup() {
    echo ""
    echo "trapped EXIT, cleaning up ..."
    echo "Removing fork remote '${FORK_REMOTE_NAME}' ..."
    git remote rm fork
    echo "Done cleaning up"
}

function ensure_dependencies() {
    trap 'cleanup' EXIT

    echo "Ensure git configured ..."
    # Using env vars overrides system/global/local git config and does not
    # persist if this script exits early
    export GIT_AUTHOR_EMAIL="${GIT_EMAIL}"
    export GIT_COMMITTER_EMAIL="${GIT_EMAIL}"
    export GIT_AUTHOR_NAME="${GIT_NAME}"
    export GIT_COMMITTER_NAME="${GIT_NAME}"

    echo "Ensure fork remote '${FORK_REMOTE_NAME}' exists ..."
    # setup the fork remote
    # TODO: ideally we would use ssh to push instead; storing the token in the
    #       url means we need to avoid leaking the remote url
    if git remote get-url "${FORK_REMOTE_NAME}" 2>/dev/null; then
        git remote set-url "${FORK_REMOTE_NAME}" "${fork_private_url}"
    else
        git remote add "${FORK_REMOTE_NAME}" "${fork_private_url}"
    fi
    git fetch "${FORK_REMOTE_NAME}"

    echo "Ensure gcloud creds are working ..."
    gcloud config list

    echo "Ensure GITHUB_TOKEN is non-empty ..."
    if [ -z "${GITHUB_TOKEN}" ]; then
      >&2 echo "ERROR: GITHUB_TOKEN is empty"
      exit 1
    fi

    echo "Ensure pr-creator is installed ..."
    if ! command -v "pr-creator" >/dev/null; then
        pushd "${TEST_INFRA_DIR}"
        mkdir -p "${AUDIT_BIN_DIR}"
        go build -o "${AUDIT_BIN_DIR}/pr-creator" robots/pr-creator/main.go
        export PATH="${AUDIT_BIN_DIR}:${PATH}"
        popd
    fi
}

function run_audit() {
    echo "Running audit script to export GCP resources ..." >&2
    "${audit_dir}/audit-gcp.sh" "$@"
}

function push_changes_if_any() {
    echo "Identifying changes ..." >&2
    git status --porcelain "${audit_dir}"
    echo "Adding changes ..." >&2
    # TODO: use a branch instead of HEAD?
    git add "${audit_dir}"
    echo "Committing changes ..." >&2
    git commit -m "audit: update as of $(date +%Y-%m-%d)"
    echo "Fetching fork remote '${FORK_REMOTE_NAME}' ..." >&2
    if git fetch "${FORK_REMOTE_NAME}" "${FORK_BRANCH}"; then
        echo "Verifying whether HEAD differs from ${fork_public_url}/tree/${FORK_BRANCH} ..."
        if git diff --quiet HEAD "${FORK_REMOTE_NAME}/${FORK_BRANCH}" -- "${audit_dir}"; then
            echo "No new changes to push, exiting early..." >&2
            exit
        fi
    fi

    echo "Pushing HEAD to ${FORK_BRANCH} in ${fork_public_url}..." >&2
    git push -f "${FORK_REMOTE_NAME}" "HEAD:${FORK_BRANCH}" 2>/dev/null
}

function create_or_update_audit_pr() {
    echo "Creating or updating PR to merge ${FORK_GITHUB_USER}:${FORK_BRANCH} into ${BASE_GITHUB_USER}:${BASE_BRANCH}..." >&2
    local args=(
        --github-token-path="${GITHUB_TOKEN_PATH}"
        --org="${BASE_GITHUB_USER}"
        --repo="${BASE_GITHUB_REPO}"
        --branch="${BASE_BRANCH}"
        --source="${FORK_GITHUB_USER}:${FORK_BRANCH}"
        --head-branch="${FORK_BRANCH}"
        --title="audit: update as of $(date +%Y-%m-%d)"
        --body="Audit Updates wg-k8s-infra"
        --confirm
    )
    pr-creator "${args[@]}"
}

#
# main
#

function main() {
    ensure_dependencies
    run_audit "$@"
    push_changes_if_any
    create_or_update_audit_pr
    echo "Done!"
}

main "$@"
