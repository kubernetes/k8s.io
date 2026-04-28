## How to deploy cert-manager

To bootstrap (per the [cert-manager getting started
guide](https://cert-manager.io/v0.13-docs/installation/kubernetes/#installing-with-regular-manifests)):

- Have [access](https://github.com/kubernetes/k8s.io/blob/main/running-in-community-clusters.md) to the GKE cluster `aaa`.

- First time install, someone with `cluster-admin` permissions needs to setup the following `clusterrolebinding`:
```console
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)
```

- From the `apps/cert-manager` directory run:
```console
./deploy.sh
```

This will set up cluster-wide webhooks and issuers, you can subsequently create
`Certificate` resources in other namespaces without repeating these steps.
