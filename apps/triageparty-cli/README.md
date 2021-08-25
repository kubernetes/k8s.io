# Triage Party for the SIG-CLI Team

[triage-party](https://github.com/google/triage-party) is used to facilitate the triage process during a kubernetes milestone.

Please checkout [https://cli.triage.k8s.io](https://cli.triage.k8s.io) and feel free to provide any feedback via an issue or [sig-cli](https://app.slack.com/client/T09NY5SBT/C2GL57FJ4) on [https://kubernetes.slack.com/](slack).

## Setup / Configuration

The collections and rules used by Triage Party are located in the [configmap](configmap.yaml).

The GitHub token is stored in Secret Manager in the `kubernetes-public` project, with access granted to members of `k8s-infra-rbac-triageparty-cli@kubernetes.io`.

## How to deploy

- Have [access](https://github.com/kubernetes/k8s.io/blob/main/running-in-community-clusters.md) to the GKE cluster `aaa`.

- From the `triageparty-cli` directory run:

```shell
./deploy.sh
```
