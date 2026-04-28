# infra/aws/terraform/test-artifacts.k8s.io

Terraform to provision AWS infra for supporting artifacts-sandbox.k8s.io.

This is a cut-down version of artifacts.k8s.io for testing / development.

## Goals

- create publicly-readable regional S3 buckets for serving Kubernetes non-image artifacts,
  as served on artifacts.k8s.io (prod) and artifacts-sandbox.k8s.io (sandbox).

## Applying the Terraform

```bash
terraform apply
```

## State management

The state of the Terraform is currently stored in a private bucket in the CNCF account

```bash
aws s3 mb s3://test-artifacts-k8s-io-tfstate --region us-east-2
```

## Notes

This is a very limited configuration for development, aiming to be simple and low-cost.

The staging/prod configuration validation is provided by the artifacts.k8s.io configuration.
