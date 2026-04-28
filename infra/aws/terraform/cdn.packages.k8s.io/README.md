# `cdn.packages.k8s.io`

This directory contains Terraform configs used to manage the following
resources:

- S3 buckets used for storing and serving packages
- Configuration and bucket policies for said S3 buckets
- CloudFront distribution used a CDN for these S3 buckets to reduce costs
- ACM certificate for domain used with CloudFront

## AWS Access

We currently use the `provisioner` IAM user to apply these Terraform configs.
Credentials for that user are located in 1Password.

The given IAM user is managed with CloudFormation Stack located in
[`infra/aws/cloudformation/iam/cdn.packages.k8s.io`][cloudformation].

[cloudformation]: https://github.com/kubernetes/k8s.io/tree/main/infra/aws/cloudformation/iam/cdn.packages.k8s.io

## Applying Terraform Configs

These Terraform configs support two different environments implemented as
[Terrraform workspaces][tf-worksapces]: `prod` (production) and `canary`.

Before getting started, it's mandatory to choose the correct Terraform
workspace:

```shell
WORKSPACE_NAME=canary make select # can also specify "prod"
```

After that, you can plan your changes using the following Make target:

```shell
make plan
```

Similar, you can apply your changes using the following Make target:

```shell
make apply
```

You can list available Make targets and their description in the following
way:

```shell
make help
```

## Updating `.lock` File

The `.lock` file can be easily updated using the following Make target:

```shell
make platforms-lock
```

That way, the `.lock` file will include all used providers and their hashes
for the most common platforms.

## Destroying Resources

If you ever need to destroy resources, you can use the following Make target:

```shell
make destroy
```

This is very dangerous and discouraged. This can eventually be used only
on canary in some special cases.

[tf-workspaces]: https://developer.hashicorp.com/terraform/language/state/workspaces
