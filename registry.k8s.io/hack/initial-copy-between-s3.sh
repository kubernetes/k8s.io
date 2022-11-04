#!/bin/bash

# Copyright 2022 The Kubernetes Authors.
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

# Dependencies
# - rclone
# - awscli

# Usage
#   sync all:       ./initial-copy-between-s3.sh
#   specify region: ./initial-copy-between-s3.sh <REGION>

# Extra usage
#   launch parallel sync using tmate
#     for REGION in $(./hack/initial-copy-between-s3.sh regions | yq e '.regions[]' -P - | xargs); do tmate -F -v -S "${TMATE_SOCKET:-/tmp/tmate.socket}" new-window -d -c "$PWD" -n sync-to-"${REGION:-}" "bash -x ./hack/initial-copy-between-s3.sh \"${REGION:-}\""; done

function sync-a-region {
    REGION="${1:-}"
    DESTINATION="s3dest:prod-registry-k8s-io-${REGION:-}"
    if [ ! -f /var/run/secrets/aws-iam-token/serviceaccount/token ]; then
      unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
      JSON=$(aws sts assume-role \
          --role-arn "arn:aws:iam::513428760722:role/registry.k8s.io_s3writer"  \
          --role-session-name "${CALLER_ID:-}-registry.k8s.io_s3writer" \
          --duration-seconds 43200 \
          --output json || exit 1)

      AWS_ACCESS_KEY_ID=$(echo "${JSON}" | jq --raw-output ".Credentials[\"AccessKeyId\"]")
      AWS_SECRET_ACCESS_KEY=$(echo "${JSON}" | jq --raw-output ".Credentials[\"SecretAccessKey\"]")
      AWS_SESSION_TOKEN=$(echo "${JSON}" | jq --raw-output ".Credentials[\"SessionToken\"]")
      export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    fi

    RCLONE_CONFIG="$(mktemp -t rclone-"${REGION:-}"-XXXXX.conf)"
    echo "Wrote rclone config to '${RCLONE_CONFIG:-}'"

    cat << EOF > "${RCLONE_CONFIG:-}"
[gcs]
type = google cloud storage
bucket_acl = private

[s3]
type = s3
provider = AWS
env_auth = true
region = us-east-2

[s3dest]
type = s3
provider = AWS
env_auth = true
region = ${REGION}
EOF
    echo "Running sync between '${SOURCE:-}' and '${DESTINATION:-}'"
    rclone sync --config "${RCLONE_CONFIG:-}" -P "${SOURCE:-}" "${DESTINATION:-}"
}

REGIONS=(
    ap-northeast-1
    ap-south-1
    ap-southeast-1

    eu-central-1
    eu-west-1

    us-east-1
    us-east-2
    us-west-1
    us-west-2
)
if [ "${1}" = "regions" ]; then
    echo "regions:"
    for REGION in "${REGIONS[@]}"; do
        echo "- ${REGION:-}"
    done
    exit 0
fi
SOURCE=s3:prod-registry-k8s-io-us-east-2

CALLER_ID="$(aws sts get-caller-identity --output json | jq -r .UserId)"

SELECTED_REGION="${1:-}"
FOUND_REGION=false
for REGION in "${REGIONS[@]}"; do
    if [ "${REGION:-}" = "${SELECTED_REGION:-}" ]; then
        FOUND_REGION=true
    fi
done
if [ ! "${FOUND_REGION:-}" = true ]; then
    echo "No region specified of: ${REGIONS[*]}"
    echo "Will sync all."
    for REGION in "${REGIONS[@]}"; do
        sync-a-region "${REGION:-}"
    done
    exit 0
fi

sync-a-region "${SELECTED_REGION:-}"
