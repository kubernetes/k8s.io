#!/bin/bash

set -e
set -x

for s in a b c d; do
  ID=e2e-kops-2020-03-15-$s
  aws organizations create-account --email k8s-infra-aws-admins+${ID}@kubernetes.io --account-name ${ID}

  while [ 1 ]; do
    sleep 10

    ORGID=`aws organizations list-accounts | jq -r ".Accounts[] | select(.Name==\"${ID}\") | .Id"`
    if [[ -n "${ORGID}" ]]; then
      break
    fi
  done

  echo "ORGID: ${ORGID}"

  cat >> ~/.aws/config <<EOF

[profile ${ID}]
  role_arn = arn:aws:iam::${ORGID}:role/OrganizationAccountAccessRole
  source_profile = cncf
EOF

  aws iam create-user --profile ${ID} --user-name ${ID}

  aws iam create-access-key --profile ${ID} --user-name ${ID} > ${ID}.json

done
