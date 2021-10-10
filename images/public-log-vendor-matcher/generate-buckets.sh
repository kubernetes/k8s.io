#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")"
SCRIPT_DIR="$(realpath "$(pwd)")"
GIT_ROOT="$(git rev-parse --show-toplevel)"

# ls -1 "${GIT_ROOT}"/audit/projects/*/buckets/ \
#     | grep -E '^k8s-artifacts|^k8s-staging|.*\.artifacts.k8s-artifacts-prod.appspot.com' \

(
    for B in "${GIT_ROOT}"/audit/projects/*/buckets/*; do
        BUCKET_NAME="$(basename "${B}")"
        if echo "${BUCKET_NAME}" \
            | grep -E '^k8s-artifacts|^k8s-staging|.*\.artifacts.k8s-artifacts-prod.appspot.com' \
            | grep -v '^.*-gcb$'; then
            echo "${BUCKET_NAME}"
        fi
    done
) \
    | sort \
    | uniq \
    | cat > "${SCRIPT_DIR}/buckets.txt"
