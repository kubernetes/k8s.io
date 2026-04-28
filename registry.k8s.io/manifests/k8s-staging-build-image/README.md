# k8s-staging-build-image GCR

This GCR is to host staging container images that are used to build k8s, like **kube-cross**.

## Build image

To build the kube-cross image:

```shell
git clone https://github.com/kubernetes/kubernetes.git
cd kubernetes/build/build-image/cross/
REGISTRY=gcr.io/k8s-staging-build-image make push
```

Note: this requires `kubernetes/kubernetes#79911` [1].

[1]: https://github.com/kubernetes/kubernetes/pull/79911