# slack-infra

Cluster resources to deploy the following apps from [kubernetes-sigs/slack-infra]:

- slack-event-log
- slack-moderator
- slack-moderator-words
- slack-welcomer
- slack-post-message
- slackin

None of the resources have a namespace defined

## How to deploy

Ensure you have [access to the cluster]

Ensure you are a member of both:
- k8s-infra-cluster-admins@kubernetes.io (for access to Kubernetes secrets in-cluster)
- k8s-infra-rbac-slack-infra@kubernetes.io (for access to Secret Manager secrets for slack-infra)

From within this directory, run `deploy.sh`

[kubernetes-sigs/slack-infra]: https://github.com/kubernetes-sigs/slack-infra
[access to the cluster]: https://github.com/kubernetes/k8s.io/blob/main/running-in-community-clusters.md#access-the-cluster
