# GSuite Groups Reconciler

This tool automates the management of Google Workspace Groups belonging to kubernetes.io domain.

- [Making changes](#making-changes)
  - [Staging access groups](#staging-access-groups)
- [Manual deploy](#manual-deploy)

## Making changes

- Edit your SIG's `groups.yaml`, e.g. [`sig-release/groups.yaml`][/groups/sig-release/groups.yaml]
- If adding or removing a group, edit [`restrictions.yaml`] to add or remove the group name
- Use `make test` to ensure the changes meet conventions
- Open a pull request
- When the pull request merges, the [post-k8sio-groups] job will deploy the changes

### Staging access groups

Google Groups for granting push access to container repositories and/or buckets
must be of the form:

```console
k8s-infra-staging-<project-name>@kubernetes.io`
```

**The project name has a max length of 18 characters.**

## Manual deploy

- Must be run by someone who is a member of the k8s-infra-group-admins@kubernetes.io group
- Run `gcloud auth application-default login` to login
- Use `make plan` to print a plan of proposed changes
- Use `make apply` to apply the changes proposed by `make plan`

[post-k8sio-groups]: https://testgrid.k8s.io/sig-k8s-infra-k8sio#post-k8sio-groups
