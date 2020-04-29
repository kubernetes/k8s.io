# slack-infra

## NOTE: this is not yet live or deployed (except secrets)

Cluster resources to deploy the following apps from [kubernetes-sigs/slack-infra]:

- slack-event-log
- slack-moderator
- slack-welcomer
- slackin

Secrets are stored as `secrets/{app}/{secret-name}-secret.yaml` and encrypted with git-crypt

None of the resources have a namespace defined

## How to deploy

From the "slack-infra" directory run:

```bash
# Basic resources
kubectl apply -n slack-infra -f resources/

# Secrets (have to be deployed by someone who can decrypt them)
git-crypt unlock
kubectl apply -n slack-infra -f secrets/
git-crypt lock
```

[kubernetes-sigs/slack-infra]: https://github.com/kubernetes-sigs/slack-infra
