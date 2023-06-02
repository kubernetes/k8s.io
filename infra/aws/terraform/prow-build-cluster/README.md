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

Set the `PROW_ENV` environment variable to `prod` or `canary`.

Production:

```bash
export PROW_ENV=prod
```

Canary:

```bash
export PROW_ENV=canary
```

### Differences between production and canary

* aws account
* cluster name
* canary is missing k8s-prow OIDC provider and the corresponding role
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
aws eks update-kubeconfig --region us-east-2 --name prow-canary-cluster
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
      - arn:aws:iam::468814281478:role/EKSInfraAdmin
    ```
* Canary:
    ```yaml
    args:
      - --region
      - us-east-2
      - eks
      - get-token
      - --cluster-name
      - prow-canary-cluster
      - --role-arn
      - arn:aws:iam::054318140392:role/EKSInfraAdmin
    ```

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
- Deploy Boskos
    ```bash
    kubectl apply -f ./resources/boskos
    ```
- Deploy node-problem-detector
    ```bash
    kubectl apply -f ./node-problem-detector
    ```
- [ONLY FOR PRODUCTION] Deploy the External Secrets Operator (ESO)
    ```bash
    kubectl apply -f ./resources/external-secrets
    ```
- Follow the appropriate instructions to deploy
  [node-termination-handler](./resources/node-termination-handler/README.md)
  and [the monitoring stack](./resources/monitoring/README.md)

## Removing cluster

The cluster can be removed by running the following command:

```bash
export PROW_ENV= # choose between canary/prod

make destroy
```

If you want to remove roles used for EKS creation go to `../iam/<aws_account_name>` and run `terraform destroy` command there.


## GitOps

To synchronize the state from this Git repository into the EKS cluster, we utilize [FluxCD](https://fluxcd.io/).

FluxCD provides a dedicated [CLI tool](https://fluxcd.io/flux/installation/#install-the-flux-cli). We leverage this tool in scripts to generate and monitor syncs.

The FluxCD resources are stored inside the `./resources` directory and are generated using the `./hack/flux-update.bash` script. This script prepares manifests for the [GitOps Tool Kit](https://fluxcd.io/flux/components/), generating [Sources](https://fluxcd.io/flux/components/source/), [Kustomizations](https://fluxcd.io/flux/components/kustomize/kustomization/) and [Helm Releases](https://fluxcd.io/flux/components/helm/helmreleases/). **It's important to note that the terms "Kustomization" and "Helm Release" used in this section refer specifically to FluxCD concepts.** The FluxCD Kustomization CRD serves as the counterpart to Kustomize's kustomization.yaml config file, and the Helm Release is a FluxCD CRD that defines a resource for automated controller-driven Helm releases.

The `flux-system` namespace contains all GitOps Tool Kit components, Flux Sources, and Kustomizations. Helm Releases should be deployed in the same namespace as the manifests they create. As a convention, Flux Helm Releases should be prefixed with `flux-hr-`, Kustomizations with `flux-ks-`, and sources with `flux-source-`. These naming conventions are used in our automation's discovery process.

- To install Flux GitOps Tool Kit components, run the following command:
    ```bash
    make flux-install
    ```

- To deploy Kustomizations, use the command:
    ```bash
    make flux-apply-kustomizations
    ```

### Accessing Flux

To access FluxCD, you need a kubeconfig file with broad cluster permissions and the Flux CLI installed locally. That option is reserved for cluster administrators. You can contanct them via #sig-k8s-infra Slack channel. (__TODO__: mention monitoring dashboards when ready)

### Adding New Kustomization

1. Navigate to the `./resources` directory and create a new folder to contain your manifests.
2. Open `./hack/flux-update.bash` in your editor of choice.
3. Locate the `kustomizations` variable, which contains a list of kustomizations to generate. Each element in the list corresonds to a directory inside the `./resources` folder.
4. Extend the kustomization list by adding the name of the folder you created in the first step.
5. Regenerate the kustomizations by running: `make flux-update`
6. Commit your changes and wait for your resources to appear in the cluster. If you have access to the cluster, you can use `flux get ks <kustomization-name>` to monitor the state.

### Adding New Helm Release

1. Open `./hack/flux-update.bash` in your preferred editor.
2. Create a new Helm source. If you already have a Helm source, you can skip this step.
    1. Locate the section of the script responsible for creating the `eks-charts` Helm release.
    2. Use the same pattern to create a new Helm source.
3. Create a new Helm release.
    1. Locate the section of the script responsible for creating the Helm release for `node-termination-handler`.
    2. Based on the `node-termination-handler` example, extend the script with your Helm release.
4. Regenerate the Helm releases by running: `make flux-update`
5. To deploy your Helm Release, you need to add it to an exiting Kustomization or create a new one.
6. If you have access to the cluster, you can check the status by executing: `flux get hr -n <namespace> <helm_release_name>` or `flux get hr -A` to list all Helm releases inside the cluster. (__TODO__: replace this section with grafana dashboard when ready)

### Monitoring Flux

__TODO__