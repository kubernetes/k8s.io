# verify-conformance

a Prow+GitHub bot for verifying Kubernetes conformance product submissions.

# Setup and configuration

Configure the targetted repos in [configmap.yaml](./configmap.yaml) and the deployment in [deployment.yaml](./deployment.yaml).

# Deployment

- Have [access](https://github.com/kubernetes/k8s.io/blob/main/running-in-community-clusters.md) to the GKE cluster `aaa`.

- From the `apps/verify-conformance` directory run:

```console
./deploy.sh
```
