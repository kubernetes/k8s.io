# slack-infra

Cluster resources to deploy the following apps from [kubernetes-sigs/slack-infra]:

- slack-event-log
- slack-moderator
- slack-welcomer
- slackin

Secrets are stored in Secret Manager in the `kubernetes-public` project, with
access granted to members of k8s-infra-rbac-slack-infra@kubernetes.io

None of the resources have a namespace defined

## How to deploy

From the "slack-infra" directory run:

```bash
# Basic resources
kubectl apply -n slack-infra -f resources/

# Secrets (have to be deployed by a member of k8s-infra-rbac-slack-infra@kubernetes.io)
for s in $(gcloud secrets list --project=kubernetes-public --filter="labels.app=slack-infra" --format="value(name)"); do
  gcloud secrets --project=kubernetes-public versions access latest --secret=$s |\
    kubetctl apply -n slack-infra -f -
done
```

[kubernetes-sigs/slack-infra]: https://github.com/kubernetes-sigs/slack-infra
