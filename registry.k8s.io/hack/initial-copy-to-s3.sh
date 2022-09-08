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
#   ./hack/initial-copy-to-s3.sh

SOURCE=gcs:us.artifacts.k8s-artifacts-prod.appspot.com
DESTINATION=s3:prod-registry-k8s-io-us-east-2

CALLER_ID="$(aws sts get-caller-identity --output json | jq -r .UserId)"

while true; do
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

  RCLONE_CONFIG="$(mktemp)"
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
EOF
  echo "Running sync between '${SOURCE:-}' and '${DESTINATION:-}'"
  if rclone sync --config "${RCLONE_CONFIG:-}" -P "${SOURCE:-}" "${DESTINATION:-}"; then
    exit 0;
  fi
done
