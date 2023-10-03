# infra/aws/terraform

Contains the Terraform for provisioning various resources under different AWS accounts using Terraform.

## Folders

- [registry.k8s.io](./registry.k8s.io/) :: resources and components backing registry.k8s.io

## Notes

### Pre-Commit Checks

To run the pre-commit checks, you will need to install the following:

- [pre-commit](https://pre-commit.com/)
- [tflint](https://github.com/terraform-linters/tflint)

Once installed, you can execute the checks with:

```bash
pre-commit run -a
```

### Warning for providers

An error may be displayed upon plan or apply commands, this error can be safely ignored as buckets provision.

```bash
╷
│ Warning: Provider aws is undefined
│
│   on main.tf line 35, in module "us-west-1":
│   35:     aws = aws.us-west-1
│
│ Module module.us-west-1 does not declare a provider named aws.
│ If you wish to specify a provider configuration for the module, add an entry for aws in the required_providers block within the
│ module.
│
│ (and 7 more similar warnings elsewhere)
╵
```
