# registry.k8s.io (under construction)

Kubernetes multi-vendor registry.

## Structure

- [infra/meta/asns/](./infra/meta/asns/) :: cloud-provider ASNs for use in querying the closest provider to route registry traffic to

## Accounts

To host the /registry.k8s.io/ redirector, several resources are located in accounts across cloud providers.

### AWS

In AWS the account to provide registry.k8s.io will be structured as follows

![Account structure](./registry-k8s-io-account-structure.svg)

Terraform management infra on AWS to support registry.k8s.io is available [here](../infra/aws/terraform/registry.k8s.io/README.md)
