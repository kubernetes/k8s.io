# infra/aws

Scripts, Terraform and documentation for infrastructure that the Kubernetes community runs on AWS.

## Folders

- [aws-costexplorer-export](./aws-costexplorer-export/) :: an exporter to provide viewing of AWS spending
- [terraform](./terraform/) :: contains the Terraform for provisioning various resources under different AWS accounts using Terraform

## Organization structure

Kubernetes infrastructure is nested inside of the CNCF's AWS account

```sh
CNCF root account
├── Kubernetes
│   ├── registry.k8s.io/
│   ├── ├── k8s-infra-aws-registry-k8s-io-admin@kubernetes.io
│   ├── k8s-infra-aws-root-account
│   ├── sig-release-leads
...
```

Accounts are separated out for concern and safety, e.g: sig-release, registry, etc...

Access is enabled through IAM users provisioned over in [cncf-infra/aws-infra](https://github.com/cncf-infra/aws-infra), by the managers of the CNCF AWS account.

### kubernetes/registry.k8s.io/

The accounts in this OU contain resources allocated for registry.k8s.io.
