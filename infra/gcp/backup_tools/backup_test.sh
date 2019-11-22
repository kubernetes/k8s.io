#!/usr/bin/env bash
#
# Copyright 2019 The Kubernetes Authors.
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

# USAGE NOTES
#
# Tests for backing up prod registries.
#
# This script requires 2 environment variables to be defined:
#
# 1) GOPATH: toplevel path for checking out gcrane's source code.
#
# 2) GOOGLE_APPLICATION_CREDENTIALS: path to the service account (JSON file)
# that has write access to the test backup GCRs.

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

export GCRANE_CHECKOUT_DIR="${GOPATH}/src/github.com/google/go-containerregistry"
GCRANE="${GCRANE_CHECKOUT_DIR}/cmd/gcrane/gcrane"

export CIP_CHECKOUT_DIR="${GOPATH}/src/sigs.k8s.io/k8s-container-image-promoter"
CIP_SNAPSHOT_CMD="${CIP_CHECKOUT_DIR}/cip -no-service-account -minimal-snapshot -output-format=CSV -snapshot"
# CIP_REF is the commit SHA to use for building the cip binary (used only for
# testing; not used by the actual prod backup job).
# Known-good commit from 2019-10-28
CIP_REF="1b6a872584d5560c54eb28e5354e5e71dae9d368"

SCRIPT_ROOT="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1090
source "${SCRIPT_ROOT}/backup_lib.sh"

TEST_IMAGES_FILE="${SCRIPT_ROOT}/backup_images_expected.yaml"

build_cip()
{
    local cip_path

    git clone https://github.com/kubernetes-sigs/k8s-container-image-promoter "${CIP_CHECKOUT_DIR}"
    pushd "${CIP_CHECKOUT_DIR}"
    git reset --hard "${CIP_REF}"
    make
    # Leave a symlink to the cip binary that was built from the above command.
    cip_path=$(find "$(bazel info bazel-bin)" -type f -name cip)
    ln -s "${cip_path}" .
    popd
}

# Leverage gcrane to clear a repository.
clear_test_backup_repo()
{
    local repo
    # For added safety, only delete the repo named
    # "gcr.io/k8s-gcr-backup-test-prod-bak".
    repo="${1}"

    while [[ -n $("${GCRANE}" ls -r "${repo}") ]]; do
        "${GCRANE}" ls -r "${repo}" | xargs -n1 "${GCRANE}" delete || true
    done
}

populate_test_prod_repo()
{
    local repo
    repo="${1}"
    region="${1/\.*/}"
    while read -r line; do
        image_by_sha="${line%,*}"
        image_by_tag="${line/*,/}"

        if [[ "${image_by_tag}" == "-" ]]; then
            image_by_tag="${image_by_sha}"
        fi

        # Copy the image, region-to-region.
        "${GCRANE}" \
            cp \
            "${region}.gcr.io/k8s-artifacts-prod/${image_by_sha}" \
            "${1}/${image_by_tag}"

    done < "${TEST_IMAGES_FILE}"
}

verify_repo()
{
    local repo

    repo="${1}"

    diff -u \
        <(cat "${TEST_IMAGES_FILE}") \
        <(${CIP_SNAPSHOT_CMD} "${repo}")
}

# Backup GCRs for prod.
declare -A test_repos=(
    [us.gcr.io/k8s-gcr-backup-test-prod]=us.gcr.io/k8s-gcr-backup-test-prod-bak

    # These regions are not tested, because running the test in these regions
    # would not actually help to add any useful information. The important thing
    # to test are the scripts in backup_lib.sh, and it is enough that we execute
    # them 1x in 1 region (US region).
    #[asia.gcr.io/k8s-gcr-backup-test-prod]=asia.gcr.io/k8s-gcr-backup-test-prod-bak
    #[eu.gcr.io/k8s-gcr-backup-test-prod]=eu.gcr.io/k8s-gcr-backup-test-prod-bak
)

# Check creds exist.
check_creds_exist

# Build dependencies.
build_gcrane
build_cip

# Clear test backup repos (k8s-gcr-backup-test-prod-bak). This will make
# reading from them simpler.
# NOTE: We don't bother clearing the test_repos. This is because once the images
# we should back up are in place, we can just reuse them across subsequent runs.
for repo in "${!test_repos[@]}"; do
    clear_test_backup_repo "${test_repos[$repo]}"
    clear_test_backup_repo "${repo}"
done

# Populate test_repos with images. We use a predefined list of images. Another
# option is to generate the images from scratch (as is done in the case of the
# image promoter's e2e tests), but it's probably better to define a list of
# known images to back up, because we don't have to worry about generating
# images for different architectures (we can find, e.g., Windows images directly
# from the source).
#
# We use the CSV format that the promoter uses for ease of checking later on.
for repo in "${!test_repos[@]}"; do
    populate_test_prod_repo "${repo}"
done

BACKUP_TIMESTAMP="1970/01/01/00"
# Copy each region to its backup.
for repo in "${!test_repos[@]}"; do
    copy_with_date "${repo}" "${test_repos[$repo]}" "${BACKUP_TIMESTAMP}"
done

# Verify backup contents by listing the images.
for repo in "${!test_repos[@]}"; do
    error_found=0
    if ! verify_repo "${test_repos[$repo]}/${BACKUP_TIMESTAMP}"; then
        error_found=1
    fi
done

if (( error_found )); then
    echo "FAIL"
    exit 1
fi

echo "SUCCESS"
