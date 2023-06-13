# EKS Cloud Infrastructure

AWS Cloud infrastructre behind EKS Prow Build Cluster is managed with use of Terraform.
This document is dedicated for **administrators** with access to k8s-infra-prow and k8s-infra-prow-canary AWS accounts.
The document contains instructions how to install, update and remove cloud infrastructure backing EKS Prow Build Cluster.

## Running Terraform

**WARNING: We strongly recommend using the provided Makefile to avoid
mistakes due to selecting wrong environment!!!**

We have a Makefile that can be used to execute Terraform targeting the
appropriate/correct environment. This Makefile uses the following environment
variables to control Terraform:

* `PROW_ENV` (default: `canary`, can be `prod`)
* `DEPLOY_K8S_RESOURCES` (default: `true`) - whether to deploy Kubernetes
  resources defined via Terraform. Reasons why it couldn't be done in one step
  can be found [here](https://github.com/hashicorp/terraform-provider-kubernetes-alpha/issues/199#issuecomment-832614387).
* `TF_ARGS` (default: none) - additional command-line flags and arguments
  to provide to Terraform

### Commands

**WARNING: Make sure to read the whole document before creating a cluster
for the first time as the additional steps are needed!**

Clean to avoid using cached state of the other cluster.

```bash
make clean
```

Init (**make sure to run this command before getting started with configs**):

```bash
make init
```

Plan:

```bash
make plan
```

Apply:

```bash
make apply
```

Destroy:

```bash
make destroy
```

## Provisioning Cluster

Running installation from scratch is different than consecutive invocations of
Terraform.

We first need to create an IAM role that we're going later to assume and use
for creating the cluster. Note that the principal that created the cluster
is considered as a cluster admin, so we want to make sure that we assume
the IAM role before starting the cluster creation process. This is done in a
separate terraform scripts located in [iam folder](../iam/).

Additionally, we can't provision a cluster and deploy Kubernetes resources in
the same Terraform run. That's because Terraform cannot plan Kubernetes
resources without the cluster being created, so we first create the cluster,
then run Terraform again to deploy Kubernetes resources.

That said, the cluster creation is done in four phases:

- Phase 1: create the IAM provisioner role and policies (see [iam](../iam/))
- Phase 2: create infrastructure **without** Kubernetes resources
- Phase 3: deploy the Kubernetes resources managed by Terraform
- Phase 4: deploy the Kubernetes resources not managed by Terraform

**WARNING: Before getting started, make sure the `PROW_ENV` environment
variable is set to the correct value!!!**

### Phase 0: preparing the environment

Before getting started, make sure to set the needed environment variables:

```bash
export PROW_ENV=canary # or prod
export DEPLOY_K8S_RESOURCES=false
```

### Phase 1: creating the IAM provisioner role and policies

See [iam folder](../iam/)

### Phase 2: create the EKS cluster

With the IAM role in place, we can assume it and use it to use it to create the
EKS cluster and other needed resources.

```bash
DEPLOY_K8S_RESOURCES=false make apply
```

### Phase 3: deploy the Kubernetes resources

With the EKS cluster in place, we can deploy Kubernetes resources managed by
Terraform:

```bash
DEPLOY_K8S_RESOURCES=true make apply
```

At this point, the cluster should be fully functional. You should fetch
kubeconfig before proceeding as described at the beginning of this document.

### Phase 4: deploy the Kubernetes resources that are not managed by Terraform

We utilize FluxCD to manage the majority of workloads running on our EKS clusters.
[This section](./GitOps.md#setting-up-eks-cluster) provides instructions for setting up FluxCD on a new cluster.

## Removing cluster

The cluster can be removed by running the following command:

```bash
export PROW_ENV= # choose between canary/prod

make destroy
```

If you want to remove roles used for EKS creation go to `../iam/<aws_account_name>` and run `terraform destroy` command there.
