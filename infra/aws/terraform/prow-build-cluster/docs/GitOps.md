# GitOps

To synchronize the state from this Git repository into the EKS cluster, we utilize [FluxCD](https://fluxcd.io/).

FluxCD provides a dedicated [CLI tool](https://fluxcd.io/flux/installation/#install-the-flux-cli).
We leverage this tool in scripts to generate and monitor syncs.

## Conventions

The FluxCD resources are stored inside the [resources directory](../resources/) and are generated using the [./hack/flux-update.bash](../hack/flux-update.bash) script. This script prepares manifests for the [GitOps Tool Kit](https://fluxcd.io/flux/components/), generating [Sources](https://fluxcd.io/flux/components/source/), [Kustomizations](https://fluxcd.io/flux/components/kustomize/kustomization/) and [Helm Releases](https://fluxcd.io/flux/components/helm/helmreleases/). **It's important to note that the terms "Kustomization" and "Helm Release" used in this section refer specifically to FluxCD concepts.** The FluxCD Kustomization CRD serves as the counterpart to Kustomize's kustomization.yaml config file, and the Helm Release is a FluxCD CRD that defines a resource for automated controller-driven Helm releases.

The `flux-system` namespace contains all GitOps Tool Kit components, Flux Sources, and Kustomizations. Helm Releases should be deployed in the same namespace as the manifests they create. As a convention, Flux Helm Releases should be prefixed with `flux-hr-`, Kustomizations with `flux-ks-`, and sources with `flux-source-`. These naming conventions are used in our automation's discovery process.

## Setting up EKS Cluster

* To install Flux GitOps Tool Kit components, run the following command:
    ```bash
    make flux-install
    ```

* To deploy Kustomizations, use the command:
    ```bash
    make flux-apply-kustomizations
    ```

## Interacting with Flux

### Changing Existing Manifests

If you need to modify any existing resources in the [resources directory](../resources/), feel free to make the necessary changes. Once your pull request (PR) is merged into the `main` branch, Flux will automatically detect the update and apply it to the Production EKS Prow Build Cluster.

### Adding New Kustomization

1. Navigate to the [resources directory](../resources/) and create a new folder to contain your manifests.
2. Open [./hack/flux-update.bash](../hack/flux-update.bash) in your editor of choice.
3. Locate the `kustomizations` variable, which contains a list of kustomizations to generate. Each element in the list corresonds to a directory inside the [resources folder](../resources/).
4. Extend the kustomization list by adding the name of the folder you created in the first step.
5. Regenerate the kustomizations by running: `make flux-update`
6. Commit your changes and wait for your resources to appear in the cluster. Track the progess of reconciliation on a dedicated [Grafana Dashboard Panel](https://monitoring-eks.prow.k8s.io/d/flux-cluster/flux-cluster-stats?viewPanel=33)

### Adding New Helm Release

1. Open [./hack/flux-update.bash](../hack/flux-update.bash) in your preferred editor.
2. Create a new Helm source. If you already have a Helm source, you can skip this step.
    1. Locate the section of the script responsible for creating the `eks-charts` Helm release.
    2. Use the same pattern to create a new Helm source.
3. Create a new Helm release.
    1. Locate the section of the script responsible for creating the Helm release for `node-termination-handler`.
    2. Based on the `node-termination-handler` example, extend the script with your Helm release.
4. Regenerate the Helm releases by running: `make flux-update`
5. To deploy your Helm Release, you need to add it to an exiting Kustomization or [create a new one](./GitOps.md#adding-new-kustomization).
6. Commit your changes and wait for your resources to appear in the cluster. Track the progess of reconciliation on a dedicated [Grafana Dashboard Panel](https://monitoring-eks.prow.k8s.io/d/flux-cluster/flux-cluster-stats?viewPanel=33)

### Admin access

To access FluxCD, you need a kubeconfig file with broad cluster permissions and the Flux CLI installed locally. That option is reserved for cluster administrators. You can contanct them via #sig-k8s-infra Slack channel.

## Monitoring Flux on Grafana

To help with identifying problems and monitor the status of syncronisation one can use two public Grafana Dashboards:
* [Flux Cluster Stats](https://monitoring-eks.prow.k8s.io/d/flux-cluster/flux-cluster-stats) - contains information about reconciliation status of deployed Flux resources.
* [Flux Control Plane](https://monitoring-eks.prow.k8s.io/d/flux-control-plane/flux-control-plane) - Offers various charts, including resource utilization of Flux controllers.

## Known Issues

Flux Helm Releases can ocassionally fail with `upgrade retries exhausted` error (so far it happend once in the span of two months). It's a [know issue](https://github.com/fluxcd/helm-controller/issues/454) and the workaround for now is following:
```bash
flux suspend hr <release_name>
flux resume hr <release_name>
```
**NOTE**: This workaround requires kubeconfig of affected cluster and fluxcli binary installed on a local filesystem.
