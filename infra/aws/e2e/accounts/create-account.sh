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

# This script creates an account and grants it permissions

ID=${1}

export AWS_PROFILE=cncf

YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`

ACCOUNT_NAME="image-builder-aws-${YEAR}-${MONTH}-${DAY}-${ID}"
echo "Creating account ${ACCOUNT_NAME}"
aws organizations create-account --email k8s-infra-aws-admins+image${YEAR}${MONTH}${DAY}${ID}@kubernetes.io --account-name ${ACCOUNT_NAME} --tags Key=boskos-pool,Value=image-builder-aws

# TODO: Wait for creation here?


ACCOUNT_JSON=`aws organizations list-accounts --output=json  | jq ".Accounts[] | select(.Name==\"${ACCOUNT_NAME}\")"`

ACCOUNT_ORG_ID=`echo ${ACCOUNT_JSON} | jq -r .Arn | cut -f3 -d/`
echo "Account organization id is ${ACCOUNT_ORG_ID}"

cat >> ~/.aws/config <<EOF

[profile ${ACCOUNT_NAME}]
role_arn = arn:aws:iam::${ACCOUNT_ORG_ID}:role/OrganizationAccountAccessRole
source_profile = cncf
EOF

# Setting the IAM user name the same as the account name makes audit logs easier to read 
USER_NAME=${ACCOUNT_NAME}
aws --profile ${ACCOUNT_NAME} iam create-user --user-name ${USER_NAME}

# Grant permissions needed by CAPA / Test Accounts
# TODO: More precise permissions?
aws --profile ${ACCOUNT_NAME} iam attach-user-policy --user-name ${USER_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws --profile ${ACCOUNT_NAME} iam attach-user-policy --user-name ${USER_NAME} --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
# Grant permission to use CloudFormation
aws --profile ${ACCOUNT_NAME} iam attach-user-policy --user-name ${USER_NAME} --policy-arn arn:aws:iam::aws:policy/AWSDeepRacerCloudFormationAccessPolicy
# Per https://github.com/kubernetes/k8s.io/issues/984
aws --profile ${ACCOUNT_NAME} iam attach-user-policy --user-name ${USER_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess


# Create the key and store into boskos

# TODO: Turn off echoing here so we don't echo the secret?

ACCESS_KEY=`aws --profile ${ACCOUNT_NAME} iam create-access-key --user-name ${ACCOUNT_NAME}`
ACCESS_KEY_ID=`echo ${ACCESS_KEY} | jq -r .AccessKey.AccessKeyId`
ACCESS_KEY_SECRET=`echo ${ACCESS_KEY} | jq -r .AccessKey.SecretAccessKey`


NAMESPACE=boskos

cat <<EOF | kubectl apply -f -
apiVersion: boskos.k8s.io/v1
kind: ResourceObject
metadata:
  name: "${ACCOUNT_NAME}"
  namespace: "${NAMESPACE}"
  labels:
    cloud-provider: aws
    aws-organization-id: "${ACCOUNT_ORG_ID}"
spec:
  type: aws-account
status:
  #owner: ""
  #state: free
  userData:
    access-key-id: "${ACCESS_KEY_ID}"
    secret-access-key: "${ACCESS_KEY_SECRET}"
EOF
