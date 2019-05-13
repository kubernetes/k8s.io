# Managing GKE clusters for kubernetes infrastructure

This repository is for things that are used to administer GKE clusters for Kubernetes infrastructure.

## Prerequiste tools

- [kubectl]
- [gcloud]

## Requirements

- A GCP account with the IAM role [Owner] is required

## Usage

**Warning**: all parameters are hardcoded for the moment

```console
$./ensure-canary-gke.sh
```

<!--links-->
[gcloud]: https://cloud.google.com/sdk/docs/
[kubectl]: https://kubernetes.io/docs/setup/independent/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
[Owner]: https://cloud.google.com/iam/docs/understanding-roles
