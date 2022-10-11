# Manually syncing buckets

**NOTE**: we are no longer manually syncing buckets, however this may be a useful
fallback reference.

## Background

In the CNCF AWS accounts, there are two accounts of concern:

- _cncf/kubernetes/k8s-infra-accounts_
- _cncf/kubernetes/registry.k8s.io/registry.k8s.io_admin_

Using an IAM user inside of the k8s-infra-accounts account, it is possible to write to the registry.k8s.io mirror buckets.

## Logging in

Log in as an IAM user, which has the ability to assume the _registry.k8s.io_s3writer_ role:

```bash
aws configure
```

## Assuming roles

In order to gain permissions to write to the buckets, it is required to call STS to assume the _registry.k8s.io_s3writer_ role:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
JSON=$(aws sts assume-role \
  --role-arn "arn:aws:iam::513428760722:role/registry.k8s.io_s3writer"  \
  --role-session-name registry.k8s.io_s3writer \
  --duration-seconds 3600 \
  --output json || exit 1)

export \
  AWS_ACCESS_KEY_ID=$(echo "${JSON}" | jq --raw-output ".Credentials[\"AccessKeyId\"]") \
  AWS_SECRET_ACCESS_KEY=$(echo "${JSON}" | jq --raw-output ".Credentials[\"SecretAccessKey\"]") \
  AWS_SESSION_TOKEN=$(echo "${JSON}" | jq --raw-output ".Credentials[\"SessionToken\"]")
```

## Set up rclone

Configure rclone to auth both with GCS and S3

```bash
cat << EOF > ~/.rclone.conf
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
```

## Performing the sync

The following set of commands will perform a sync, first between GCS US region and S3 us-east-2, then between S3 us-east-2 and the remaining regions

```bash
REGIONS=(
    prod-registry-k8s-io-ap-southeast-1
    prod-registry-k8s-io-ap-southeast-2
    prod-registry-k8s-io-ap-south-1

    prod-registry-k8s-io-us-west-1
    prod-registry-k8s-io-us-west-2
    prod-registry-k8s-io-us-east-1

    prod-registry-k8s-io-eu-central-1
    prod-registry-k8s-io-eu-west-1
)

# initial sync (gcs us -> s3 us)
rclone sync -P gcs:us.artifacts.k8s-artifacts-prod.appspot.com s3:prod-registry-k8s-io-us-east-2

for REGION in "${REGIONS[@]}"; do
  rclone config update s3 region "${REGION}"
  rclone sync -P s3:prod-registry-k8s-io-us-east-2 "s3:${REGION}"
done
```
