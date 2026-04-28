# IAM for Boskos accounts

This directory contains CloudFormation templates needed to provision IAM
resources to be used for managing Boskos accounts.

## Background

We have many AWS accounts to be used with Boskos. We want to manage them in
an efficient way with Terraform. We also want to avoid creating different
IAM users for each account as managing that number of credentials and Terraform
states is hard.

## Benefits of Using CloudFormation

If we wanted to use Terraform to manage IAM user and roles for these accounts,
we would need to:

- Create an IAM user and access key for that user in each account
- Create a S3 bucket in each account to be used for storing Terraform state
- Have a dedicated Terraform backend for each account

In any case, tasks 1 and 2 must be done manually or with CloudFormation.
That said, I think that completely managing IAM with CloudFormation is easier
and more scalable.

Note: we don't want to use StackSets because delegating access can be too
complicated, see [the following thread][cf-stacksets] for more details.

[cf-stacksets]: https://github.com/kubernetes/k8s.io/pull/5213#discussion_r1187138717

## Architecture

* We have an IAM user (`provisioner`) in the first Boskos account
  (`eks-e2e-boskos-001`).
* We have IAM roles (`Provisioner`) in all Boskos accounts
* The `Provisioner` IAM role is configured in a way that `provisioner` user can
  assume it
* The `Provisioner` IAM role has a restrictive policy with as least permissions
  as possible
* Resources that support tagging are tagged with `Boskos=Ignore` to ensure that
  aws-janitor ignores these resources

## Applying CloudFormation Stacks

**IMPORTANT: It's required to tag each Stack with `Boskos=Ignore` upon creating
the Stack to ensure that aws-janitor ignores these resources.**

There are two CloudFormation Stacks for `eks-e2e-boskos` accounts:

- `eks-e2e-boskos-001/eks-e2e-boskos-001.yaml` - creates S3 bucket for Terraform
  state and `provisioner` IAM user, this stack should be applied only to
  `eks-e2e-boskos-001` account (the first Boskos account)
  - Static credentials needs to be generated manually after the stack is applied
- `provisioner-iam-role.yaml` - creates IAM role and policy, this stack should
  be applied to all Boskos accounts
  - This stack takes account ID of the first Boskos account
    (`eks-e2e-boskos-001`) as a required parameter

Stacks are applied by logging in with the root user to each Boskos account and
applying the appropriate stack (YAML file).
See [the following document][using-cf] for more details.

[using-cf]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html
