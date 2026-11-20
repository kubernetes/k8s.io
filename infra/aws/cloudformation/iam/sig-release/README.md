# CloudFormation-Managed Resources For SIG Release

This directory contains the CloudFormation template that bootstraps the
`sig-release-leads` AWS account (`433650573627`):

- S3 bucket used for Terraform state (`k8s-sig-release-tfstate`)
- IAM user, role, and policies used with Terraform to manage
  [`infra/aws/terraform/sig-release`](../../../terraform/sig-release)

## Applying/Updating CloudFormation Stacks

The stack is applied and updated by logging in with the root account to the
`sig-release-leads` AWS account and applying `cloudformation.yaml` in
`us-west-2`. See [the following document][using-cf] for more details.

After the stack is created, create an access key for the `provisioner` IAM user
and store it in the 1Password vault where Release Managers have access.

Credentials for the root account are located in 1Password where Release
Managers have access.

[using-cf]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html
