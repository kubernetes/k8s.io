# sippy

`sippy` is a tool used to aid in transparency of stability metrics.

[sippy](https://github.com/openshift/sippy) summarizes multiple test-grid dashboards with data slicing of related jobs, job runs,
and tests.  Visit (placeholder for eventual URL) to see the kube instance. 


## How to deploy sippy

- Have [access](https://github.com/kubernetes/k8s.io/blob/master/running-in-community-clusters.md) to the GKE cluster `aaa`.

- From the `apps/sippy` directory run:

```console
kubectl apply -f .
```
