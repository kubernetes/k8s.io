# IAM for Boskos accounts

This directory contains CloudFormation templates needed to provision IAM resources
to be used for managing Boskos accounts.

## Background

We have many AWS accounts to be used with Boskos. We want to manage them in
an efficient way with Terraform. We also want to avoid creating different
IAM users for each account as managing that number of credentials and Terraform
states is hard.

## Architecture

* We have an IAM user (`provisioner`) in the first Boskos account (`eks-e2e-boskos-001`).
* We have IAM roles (`Provisioner`) in all Boskos accounts
* The `Provisioner` IAM role is configured in a way that `provisioner` user can assume it
* The `Provisioner` IAM role has a restrictive policy with as least permissions as possible
* Resources that support tagging are tagged with `Boskos=Ignore` to ensure that aws-janitor ignores these resources

## Applying Stacks

Stacks are applied by logging in with the root user to each Boskos account and applying
the appropriate stack (JSON file). See the following document for more details:
https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html

It's required to tag each Stack with `Boskos=Ignore` upon creating the Stack to ensure
that aws-janitor ignores these resources.

### IAM User

This Stack is applied only to the first Boskos account. The Stack is located in
`cloudformation-user.json`.

Once the Stack is applied, `cloudformation-role.json` needs to be modified to replace
principal for the `Provisioner` role. Also, credentials needs to be created manually
once the user is created.

### IAM Role

This Stack is applied to all Boskos accounts. The Stack is located in
`cloudformation-role.json`.
