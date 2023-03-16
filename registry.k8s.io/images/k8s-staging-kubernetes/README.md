### ATTENTION ###

`k8s-staging-kubernetes` is the staging container registry for ROOT level `k8s.gcr.io` images.
Image promotion for this project is restricted to [Release Managers](https://git.k8s.io/sig-release/release-managers.md).

The following images are managed within this project:

- `cloud-controller-manager`
- `conformance` (will likely be moved to another staging project)
- `hyperkube`
- `kube-apiserver`
- `kube-controller-manager`
- `kube-proxy`
- `kube-scheduler`
- `pause`

Promotes to the following GCR locations:

- `{us,eu,asia}.gcr.io/k8s-artifacts-prod` --> `k8s.gcr.io`
- `{us,eu,asia}.gcr.io/k8s-artifacts-prod/kubernetes` --> `k8s.gcr.io/kubernetes`
