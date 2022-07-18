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

SOURCE=gcs:us.artifacts.k8s-artifacts-prod.appspot.com
DESTINATION=s3:prod-registry-k8s-io-us-east-2

while true; do
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  JSON=$(aws sts assume-role \
    --role-arn "arn:aws:iam::513428760722:role/registry.k8s.io_s3writer"  \
    --role-session-name registry.k8s.io_s3writer \
    --duration-seconds 43200 \
    --output json || exit 1)

  export \
    AWS_ACCESS_KEY_ID=$(echo "${JSON}" | jq --raw-output ".Credentials[\"AccessKeyId\"]") \
    AWS_SECRET_ACCESS_KEY=$(echo "${JSON}" | jq --raw-output ".Credentials[\"SecretAccessKey\"]") \
    AWS_SESSION_TOKEN=$(echo "${JSON}" | jq --raw-output ".Credentials[\"SessionToken\"]")

  RCLONE_CONFIG="$(mktemp)"
  echo "Wrote rclone config to '${RCLONE_CONFIG:-}'"

  cat << EOF > "${RCLONE_CONFIG:-}"
[gcs]
type = google cloud storage
bucket_acl = private

[s3]
type = s3
provider = AWS
access_key_id = $AWS_ACCESS_KEY_ID
secret_access_key = $AWS_SECRET_ACCESS_KEY
session_token = $AWS_SESSION_TOKEN
region = us-east-2
EOF
  echo "Running sync between '${SOURCE:-}' and '${DESTINATION:-}'"
  rclone sync --config "${RCLONE_CONFIG:-}" -P "${SOURCE:-}" "${DESTINATION:-}"
  if [ $? -eq 0 ]; then
    exit 0;
  fi
done
