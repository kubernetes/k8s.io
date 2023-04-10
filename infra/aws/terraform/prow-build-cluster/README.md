# EKS-based Prow build cluster

This folder contains Terraform configs and modules needed to provision and
bootstrap an EKS-based Prow build cluster.

## Environments

There are two different environments, i.e. clusters:

* Production - the cluster that's used as a build cluster and that's connected
  to the Prow control plane and GCP
* Canary - the cluster that's used to verify infrastructure changes before
  applying them to the production cluster. **This cluster is not connected to
  the Prow Control plane or GCP**

### Choosing the environment

Set the `WORKSPACE_NAME` environment variable to `prod` or `canary`.

Production:

```bash
export WORKSPACE_NAME=prod
```

Canary:

```bash
export WORKSPACE_NAME=canary
```

### Differences between production and canary

* cluster name
* cluster admin IAM role name
* secrets manager IAM policy name
* canary is missing k8s-prow OIDC provider and the corresponding role
* subnet setup is different
* instance type and autoscaling parameters (mainly for saving)

## Interacting with clusters

You'll mainly interact with clusters using kubectl and Terraform. You need
kubeconfig for the former which can be obtained using the `aws` CLI.

Production:

```bash
aws eks update-kubeconfig --region us-east-2 --name prow-build-cluster
```

Canary:

```bash
aws eks update-kubeconfig --region us-east-2 --name prow-build-canary-cluster
```

This is going to update your `~/.kube/config` (unless specified otherwise).
Once you fetched kubeconfig, you need to update it to add assume role arguments,
otherwise you'll have no access to the cluster (e.g. you'll get Unauthorized
error).

Open kubeconfig in a text editor of your choice and update `args` for the
appropriate cluster:

* Production
    ```yaml
    args:
      - --region
      - us-east-2
      - eks
      - get-token
      - --cluster-name
      - prow-build-cluster
      - --role-arn
      - arn:aws:iam::468814281478:role/Prow-Cluster-Admin
    ```
* Canary:
    ```yaml
    args:
      - --region
      - us-east-2
      - eks
      - get-token
      - --cluster-name
      - prow-build-canary-cluster
      - --role-arn
      - arn:aws:iam::468814281478:role/canary-Prow-Cluster-Admin
    ```

## Running Terraform

**WARNING: We strongly recommend using the provided Makefile to avoid
mistakes due to selecting wrong environment!!!**

We have a Makefile that can be used to execute Terraform targeting the
appropriate/correct environment. This Makefile uses the following environment
variables to control Terraform:

* `WORKSPACE_NAME` (default: `canary`, can be `prod`)
* `ASSUME_ROLE` (default: `true`) - whether to authenticate to AWS using
  provided credentials or by assuming the ProwClusterAdmin role
* `DEPLOY_K8S_RESOURCES` (default: `true`) - whether to deploy Kubernetes
  resources defined via Terraform
* `TF_ARGS` (default: none) - additional command-line flags and arguments
  to provide to Terraform

### Commands

**WARNING: Make sure to read the whole document before creating a cluster
for the first time as the additional steps are needed!**

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
the IAM role before starting the cluster creation process.

Additionally, we can't provision a cluster and deploy Kubernetes resources in
the same Terraform run. That's because Terraform cannot plan Kubernetes
resources without the cluster being created, so we first create the cluster,
then run Terraform again to deploy Kubernetes resources.

That said, the cluster creation is done in four phases:

- Phase 1: create the IAM role and policies
- Phase 2: create everything else
- Phase 3: deploy the Kubernetes resources managed by Terraform
- Phase 4: deploy the Kubernetes resources not managed by Terraform

**WARNING: Before getting started, make sure the `WORKSPACE_NAME` environment
variable is set to the correct value!!!**

### Phase 0: preparing the environment

Before getting started, make sure to set the needed environment variables:

```bash
export WORKSPACE_NAME=canary # or prod
export ASSUME_ROLE=false # the role to be assumed will be created in phase 1
export DEPLOY_K8S_RESOURCES=false
```

### Phase 1: creating the IAM role and policies

We're now going to create the IAM role and attach policies to it.
This step is done by applying the appropriate `iam` module:

```bash
TF_ARGS="-target=module.iam" make apply
```

Ignore Terraform warnings about incomplete state, this is as expected
as we're using the `-target` flag.

### Phase 2: create the EKS cluster

With the IAM role in place, we can assume it and use it to use it to create the
EKS cluster and other needed resources.

First, set the `ASSUME_ROLE` environment variable to `true`:

```bash
export ASSUME_ROLE=true
```

Then run Terraform again:

```bash
make apply
```

### Phase 3: deploy the Kubernetes resources

With the EKS cluster in place, we can deploy Kubernetes resources managed by
Terraform. First, make sure to set the `DEPLOY_K8S_RESOURCES` environment
variable to `true`:

```bash
export DEPLOY_K8S_RESOURCES=true
```

Then run the `apply` command again:

```bash
make apply
```

At this point, the cluster should be fully functional. You should fetch
kubeconfig before proceeding as described at the beginning of this document.

### Phase 4: deploy the Kubernetes resources not managed by Terraform

Not all Kubernetes resources are managed by Terraform. We're working on
streamlining this, but until then, you have to deploy those resources manually.

- Create required namespaces:
    ```bash
    kubectl apply -f ./resources/namespaces.yaml
    ```
- Create cluster roles and role bindings:
    ```bash
    kubectl apply -f ./resources/rbac
    ```
- Create required resources in kube-system and test-pods namespaces:
    ```bash
    kubectl apply -f ./resources/kube-system
    kubectl apply -f ./resources/test-pods
    ```
- Follow the appropriate instructions to deploy
  [node-termination-handler](./resources/node-termination-handler/README.md)
  and [the monitoring stack](./resources/monitoring/README.md)

## Removing cluster

The cluster can be removed by running the following command:

```bash
export WORKSPACE_NAME= # choose between canary/prod

make destroy
```
