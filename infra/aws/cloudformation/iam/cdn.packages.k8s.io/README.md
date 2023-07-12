# CloudFormation-Managed Resources For `cdn.packages.k8s.io`

This directory contains CloudFormation template needed to provision:

- S3 bucket used for Terraform state
- IAM user, role, and policies used with Terraform to manage S3 bucket used for
  packages and CloudFront distribution
- IAM user and policy used by the OpenBuildService (OBS) platform to publish
  packages

## Applying/Updating CloudFormation Stacks

Stack is applied and updated by logging in with the root account to
`k8s-infra-obs-k8s-io-prod` AWS account and applying the appropriate stack
(YAML file). See [the following document][using-cf] for more details.

Credentials for the root account are located in 1Password where Release
Managers have access.

[using-cf]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html
