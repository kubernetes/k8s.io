#!/bin/bash

set -e
#set -x


toyaml() {
  local OUT=$1
  local IN=$2

  AWS_ACCESS_KEY_ID=`cat ${IN}.json | jq -r .AccessKey.AccessKeyId`
  AWS_SECRET_ACCESS_KEY=`cat ${IN}.json | jq -r .AccessKey.SecretAccessKey`

  cat > ${OUT}.yaml <<EOF
apiVersion: boskos.k8s.io/v1
kind: ResourceObject
metadata:
  name: ${OUT}
  namespace: test-pods
spec:
  type: aws-account
status:
  owner: ""
  state: free
  userData:
    access-key-id: "${AWS_ACCESS_KEY_ID}"
    secret-access-key: "${AWS_SECRET_ACCESS_KEY}"

---

EOF

}

for s in a b c d; do
  toyaml e2e-kops-$s e2e-kops-2020-03-15-$s
done
