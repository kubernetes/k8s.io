# IAM for OBS/`packages.k8s.io` account

This directory contains CloudFormation templates needed to provision IAM
resources to be used for managing AWS account backing OBS/`packages.k8s.io`
infra.

## Applying CloudFormation Stacks

Stack is applied by logging in with the root user to obs-k8s-io-prod account
and applying the appropriate stack (YAML file).
See [the following document][using-cf] for more details.

[using-cf]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html
