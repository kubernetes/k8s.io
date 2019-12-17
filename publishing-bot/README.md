# Kubernetes Publishing Bot

The publishing-bot for the Kubernetes project is running on a CNCF sponsored
GKE cluster `aaa` in the `kubernetes-public` project.

The bot is responsible for updating `go.mod`/`Godeps` and `vendor` for target repos.
To support both godeps for releases <= v1.14 and go modules for the master branch
and releases >= v1.14, we run two instances of the bot today.

The instance of the bot responsible for syncing releases <= v1.14 runs in the
`k8s-publishing-bot-godeps` namespace and the instance of the bot responsible
for syncing the master branch and releases >= v1.14 runs in the `k8s-publishing-bot`
namespace.

The code for the former can be found in the [godeps branch] and the latter in the master
branch of the publishing-bot repo.

## Permissions

The cluster can be accessed by members of the [k8s-infra-cluster-admins] and the [k8s-infra-rbac-publishing-bot]
google groups. Members can be added to the groups by updating [groups.yaml].

## Running the bot

Make sure you are at the root of the publishing-bot repo before running these commands.

### Deploying the bot

```sh
make deploy CONFIG=configs/kubernetes
```

[godeps branch]: https://github.com/kubernetes/publishing-bot/tree/godeps
[k8s-infra-cluster-admins]: https://groups.google.com/forum/#!forum/k8s-infra-cluster-admins
[k8s-infra-rbac-publishing-bot]: https://groups.google.com/forum/#!forum/k8s-infra-rbac-publishing-bot
[groups.yaml]: https://git.k8s.io/k8s.io/groups/groups.yaml
