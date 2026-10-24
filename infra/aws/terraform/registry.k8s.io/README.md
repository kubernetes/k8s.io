# AWS Infrastructure for registry.k8s.io

The resources created here are used by [archeio](https://github.com/kubernetes/registry.k8s.io/tree/main/cmd/archeio)

## Goals

- create publicly-readable regional S3 buckets for serving Kubernetes container images
- use S3 replication rules to fan out the blob replication to all the S3 buckets
- create an IAM role to provide write access into each bucket

## Extending regions

Supporting more AWS regions is simple, the steps are:

1. run the command `aws ec2 describe-regions --all-regions --query "Regions[].RegionName" --output json | jq .[] | awk '{print $0","}' | sort --version-sort` to get full set of AWS regions and update the main.tf file
1. Login to the management account and enable the new region for this account(513428760722) using AWS Organizations
1. The closest region to the AWS China regions `cn-northwest-1` & `cn-north-1` is `ap-east-1` (Hong Kong), we don't have access to the aws-cn partition.
