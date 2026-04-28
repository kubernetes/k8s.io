# Elekto

[Elekto](https://elekto.dev/) is a voting platform used to run elections for the Kubernetes community.

# Setup /Configuration

Elekto uses :

- an internal Cloud SQL instance with PostGreSQL as database engine living in `kubernetes-public`

## How to deploy Elekto

- Have [access](https://github.com/kubernetes/k8s.io/blob/main/running-in-community-clusters.md) to the GKE cluster `aaa`.

- From the `apps/elekto` directory run:

```console
./deploy.sh
```
