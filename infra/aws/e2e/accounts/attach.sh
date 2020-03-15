#!/bin/bash

set -e
set -x

for s in a b c d; do
  ID=e2e-kops-2020-03-15-$s

  for r in AmazonEC2FullAccess IAMFullAccess AWSDeepRacerCloudFormationAccessPolicy; do
    aws iam attach-user-policy --profile ${ID} --user ${ID} --policy-arn arn:aws:iam::aws:policy/${r}
  done

  aws iam list-attached-user-policies --profile ${ID} --user ${ID}
done
