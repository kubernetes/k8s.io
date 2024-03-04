# AWS Account for CAPA AMI Publication

This contains Terraform used to manage users & permissions for the **cncf-k8s-infra-aws-capa-ami** AWS account (`arn:aws:organizations::348685125169:account/o-kz4vlkihvy/819546954734`).

## Tool Requirements

* [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.6.0 or greater
* AWS CLI

## Pre-reqs

This will need to be run by someone that is an admin in the account or by someone that can assume role to give admin in the account.

## Running

Set the AWS environment variables for the user that has access to the account. 

Then run the following to disable the blocking of public AMIs:

```bash
hack/disable-block.sh
```

> NOTE: the script is used to disable the block as it doesn't naturally fit well into Terraform when running it across many regions.

Then do the usual terraform flow:

```bash
terraform plan
terraform apply
```

If its the first time its been run you can then supply the CAPA maintainers with the initial passwords for their IAM accounts.

Also one of the maintainers will need to be given the access key id and secret got IAM account to be used for automation. These have been encrypted with the gpg of one of the maintainers.

## Adding users

The CAPA maintainers have been added as IAM users. The iam user name matches their GitHub username.

Where possible the the user should be defined with **pgp_key** so that the initial password for the IAM user is encrypted.
