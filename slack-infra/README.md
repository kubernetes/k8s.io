# slack-infra

## NOTE: this is not yet live or deployed

Cluster resources to deploy the following apps from [kubernetes-sigs/slack-infra]:
- slack-event-log
- slack-moderator
- slack-welcomer
- slackin

Secrets are stored as `{app}/{secret-name}-secret.yaml` and encrypted with git-crypt

None of the resources have a namespace defined

## TODO: how to deploy

[kubernetes-sigs/slack-infra]: https://github.com/kubernetes-sigs/slack-infra
