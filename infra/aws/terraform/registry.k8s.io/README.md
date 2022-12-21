# infra/aws/terraform/registry.k8s.io

Terraform to provision AWS infra for supporting registry.k8s.io

## Goals

- create publicly-readable regional S3 buckets for serving Kubernetes container images
- create an IAM role to provide write access into each bucket
- provide a way for testing the buckets

## Applying the Terraform

In order to apply the Terraform in production, the variable of _prefix_ must be set to `prod-`, i.e

```bash
terraform apply -var prefix=prod-
```

## Testing

The variable _prefix_ can be set to prefix all variables with a value

```bash
terraform apply -var prefix=test-
```

## State management

The state of the Terraform is currently stored in a private bucket in the CNCF account

```bash
aws s3 mb s3://registry-k8s-io-tfstate --region us-east-2
```

## Notes

- currently all provider blocks will assume the role of registry.k8s.io_s3admin inside of the registry.k8s.io account (513428760722)

## Extending regions

Supporting more AWS regions is simple, the steps are:

1. add a new _aws_ provider with a region and alias in the [providers.tf](./providers.tf) file
2. add a new module block for the region in the [main.tf](./main.tf) file, including the correct region name for all three values (module name, provider+alias and region variable)
