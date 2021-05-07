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

set -ex

# This script dumps audit data for all accounts in the organization

export AWS_PROFILE=cncf
ACCOUNT_IDS=`aws organizations list-accounts --output=json | jq -r .Accounts[].Id`

AUDIT_DIR=audit/aws/

mkdir -p ${AUDIT_DIR}
for ACCOUNT_ID in ${ACCOUNT_IDS}; do
  echo "Querying account ${ACCOUNT_ID}"
  mkdir -p ${AUDIT_DIR}/accounts/${ACCOUNT_ID}/
  aws organizations describe-account --account-id ${ACCOUNT_ID} --output=json > ${AUDIT_DIR}/accounts/${ACCOUNT_ID}/account.json
  aws organizations list-tags-for-resource --resource-id ${ACCOUNT_ID} --output=json > ${AUDIT_DIR}/accounts/${ACCOUNT_ID}/tags.json

  sleep 2 # Avoid rate-limiting problems
done

# Use a temporary AWS_CONFIG_FILE, to avoid messing up the main one
export AWS_CONFIG_FILE=/tmp/aws-config

for ACCOUNT_DIR in ${AUDIT_DIR}/accounts/*/; do
  echo "Querying account ${ACCOUNT_DIR}"

  ACCOUNT_ORG_ID=`cat ${ACCOUNT_DIR}/account.json | jq -r .Account.Arn | cut -f3 -d/`
  echo "Account organization id is ${ACCOUNT_ORG_ID}"

  cat >> ${AWS_CONFIG_FILE} <<EOF

[profile account-${ACCOUNT_ORG_ID}]
role_arn = arn:aws:iam::${ACCOUNT_ORG_ID}:role/OrganizationAccountAccessRole
source_profile = cncf
EOF

  aws --profile account-${ACCOUNT_ORG_ID} iam list-users --output=json > ${ACCOUNT_DIR}/iam-users.json
  for USER_NAME in `cat ${ACCOUNT_DIR}/iam-users.json | jq -r .Users[].UserName`; do
    echo "Checking user ${USER_NAME}"
    mkdir -p ${ACCOUNT_DIR}/users/${USER_NAME}/
    aws --profile account-${ACCOUNT_ORG_ID} iam list-access-keys --user-name ${USER_NAME} --output=json > ${ACCOUNT_DIR}/users/${USER_NAME}/access-keys.json
    aws --profile account-${ACCOUNT_ORG_ID} iam list-attached-user-policies --user-name ${USER_NAME} --output=json > ${ACCOUNT_DIR}/users/${USER_NAME}/attached-policies.json
    aws --profile account-${ACCOUNT_ORG_ID} iam list-groups-for-user --user-name ${USER_NAME} --output=json > ${ACCOUNT_DIR}/users/${USER_NAME}/groups.json
    aws --profile account-${ACCOUNT_ORG_ID} iam list-user-policies --user-name ${USER_NAME} --output=json > ${ACCOUNT_DIR}/users/${USER_NAME}/policies.json
  done

  aws --profile account-${ACCOUNT_ORG_ID} iam list-groups --output=json > ${ACCOUNT_DIR}/iam-groups.json
  for GROUP_NAME in `cat ${ACCOUNT_DIR}/iam-groups.json | jq -r .Groups[].GroupName`; do
    echo "Checking group ${GROUP_NAME}"
    mkdir -p ${ACCOUNT_DIR}/groups/${GROUP_NAME}/
    aws --profile account-${ACCOUNT_ORG_ID} iam list-attached-group-policies --group-name ${GROUP_NAME} --output=json > ${ACCOUNT_DIR}/groups/${GROUP_NAME}/attached-policies.json
    aws --profile account-${ACCOUNT_ORG_ID} iam list-group-policies --group-name ${GROUP_NAME} --output=json > ${ACCOUNT_DIR}/groups/${GROUP_NAME}/policies.json
  done

  sleep 2 # Avoid rate-limiting problems
done
