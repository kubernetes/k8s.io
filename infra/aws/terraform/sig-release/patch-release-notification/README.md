# patch-release-notification

Infrastructure for the Lambda function that emails `dev@kubernetes.io` when the
cherry-pick deadline of the upcoming patch releases is approaching. The code
lives in
[kubernetes/release `cmd/patch-release-notification`](https://github.com/kubernetes/release/tree/master/cmd/patch-release-notification).

Everything runs in the `sig-release-leads` AWS account (`433650573627`),
`us-west-2`:

- SES email identity for `release-managers@kubernetes.io`
- Lambda function, deployed from a container image pinned by digest
- EventBridge rule that triggers the Lambda every day at 16:00 UTC
- IAM role for the Lambda, scoped to sending from the SES identity and writing
  its own logs
- CloudWatch log group, and an alarm that emails `alert_email` when a run fails

The Terraform state bucket, the `Provisioner` role and the ECR repository are
created by [the CloudFormation stack](../../../cloudformation/iam/sig-release).

## Prerequisites

- The CloudFormation stack is applied.
- AWS credentials for the `provisioner` IAM user (1Password). Terraform assumes
  the `Provisioner` role by itself.
- [`ko`](https://ko.build) and a checkout of
  [kubernetes/release](https://github.com/kubernetes/release).

## Build and push the image

From the kubernetes/release checkout:

```shell
REPO=433650573627.dkr.ecr.us-west-2.amazonaws.com/release-engineering/patch-release-notification

aws ecr get-login-password --region us-west-2 \
  | ko login 433650573627.dkr.ecr.us-west-2.amazonaws.com --username AWS --password-stdin

# Tags are immutable, so tag with the commit instead of latest.
KO_DOCKER_REPO="${REPO}" ko build --bare \
  --platform=linux/arm64 \
  --tags="$(git rev-parse --short HEAD)" \
  ./cmd/patch-release-notification
```

`ko` prints the image reference with its digest. Set `image_uri` in
`terraform.tfvars` to that value and open a PR.

The `--platform` must match the `architectures` of the Lambda (`arm64`).

## Deploy

```shell
terraform init
terraform plan -out=plan.out
terraform apply plan.out
```

## First deployment

1. SES sends a verification email to `sender_email`. Someone in
   `release-managers@kubernetes.io` must click the link.
1. If `alert_email` is set, SNS sends a subscription confirmation that must be
   accepted too.
1. With `no_mock = false` (the default) the email only goes to `sender_email`.
   Run the function once and check the result:

   ```shell
   aws lambda invoke --function-name patch-release-notification /dev/stdout
   ```

1. New SES accounts are in the sandbox and can only send to verified
   addresses. Request [production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html)
   before sending to `dev@kubernetes.io`.
1. `dev@kubernetes.io` moderates posts from non-members, so
   `release-managers@kubernetes.io` must be a member of it.
1. Set `no_mock = true` and apply.
