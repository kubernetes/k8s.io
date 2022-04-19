# infra/aws

Scripts, Terraform and documentation for infrastructure that the Kubernetes community runs on AWS.

## Folders

- [aws-costexplorer-export](./aws-costexplorer-export/) :: an exporter to provide viewing of AWS spending
- [terraform](./terraform/) :: contains the Terraform for provisioning various resources under different AWS accounts using Terraform

## Account structure

Kubernetes infrastructure is nested inside of the CNCF's AWS account

```sh
CNCF root account
├── Kubernetes
│   ├── k8s-infra-aws-root-account
│   ├── sig-release-leads
...
```
