
# Kubernetes clusters owned by SIG K8s-Infra

This folder contains the declarative configuration for Kubernetes clusters managed by this repo.
The general pattern is:

- Per-cluster configuration lives in `kubernetes/<cluster-name>/...`.
- Shared workloads are defined as Argo CD Applications/ApplicationSets in `kubernetes/apps/`.
- Argo CD itself runs in the `gke-utility` cluster (see `kubernetes/gke-utility/argocd/`).

We use ArgoCD to manage our cluster, you can access it at argo.k8s.io, to access the app, you need to:
- be a member of the kubernetes github org
- add your github user to the AuthorizationPolicy in this file: `kubernetes/gke-utility/argocd/extras.yaml#L62`

## Clusters managed here

Cluster directories under `kubernetes/` correspond to the clusters Argo CD manages:

- `aks-prow-build` A Prow Build Cluster in AKS
- `eks-prow-build` A Prow Build Cluster in EKS
- `eks-prow-kops` A Prow Build Cluster in EKS
- `gke-aaa` A shared GKE cluster that runs our applications
- `gke-prow` Prow Control Plane Cluster on GKE
- `gke-prow-build` A Prow Build Cluster in GKE
- `gke-prow-build-trusted` A Prow Build Cluster in GKE, for trusted/sensitive jobs
- `gke-utility` A GKE cluster running utility workloads such as ArgoCD, Atlantis, Unified Monitoring Stack, etc
- `ibm-ppc64le` A Prow Build Cluster in IBM
- `ibm-s390x` A Prow Build Cluster in IBM

Cluster registration/labels used by ApplicationSets are defined in `kubernetes/gke-utility/argocd/clusters.yaml`.

## Workloads

This repo manages many workloads; common examples include:

- `prow` this contains all components of prow deployed in test-pods namespace for all build clusters.
- `datadog`, our monitoring, security tooling on all AKS/EKS/GKE clusters


### Note

- The `gke-aaa` kubernetes manifests are not being managed by ArgoCD yet, you can find them in the `apps` folder
