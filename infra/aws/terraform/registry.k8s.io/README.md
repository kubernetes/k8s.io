# infra/aws/terraform/registry.k8s.io

Terraform to provision AWS infra for supporting registry.k8s.io

## Goals

- create publicly-readable regional S3 buckets for serving Kubernetes container images
- create an IAM role to provide write access into each bucket
- provide a way for testing the buckets

## Extending regions

Supporting more AWS regions is simple, the steps are:

1. add a new _aws_ provider with a region and alias in the [providers.tf](./providers.tf) file
2. add a new module block for the region in the [main.tf](./main.tf) file, including the correct region name for all three values (module name, provider+alias and region variable)

## Testing

The variable _prefix_ can be set to prefix all variables with a value

```bash
terraform apply -var prefix=test-
```
