# Kubernetes External Secrets

[Kubernetes External Secrets](https://github.com/external-secrets/kubernetes-external-secrets) is mainly used to ensure synchronization of secrets stored in AWS and GCP Secrets Manager to community-owned GKE cluster `aaa`.

## How to deploy

Ensure you have [access to the cluster]

Ensure you are a member of:

- k8s-infra-rbac-kubernetes-external-secrets@kubernetes.io

If you encounter any issue during the deployment, reach out to k8s-infra-cluster-admins@kubernetes.io for help.

```shell
./deploy.sh
```

[access to the cluster]: https://github.com/kubernetes/k8s.io/blob/main/running-in-community-clusters.md#access-the-cluster
