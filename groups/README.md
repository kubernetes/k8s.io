# Automation of Google Groups maintenance for k8s-infra permissions

## Making changes

- Edit `groups.yaml` to add a new group or update an existing group
- All groups MUST start with "k8s-infra-" prefix for the reconcile.go to work
- Use `make test` to ensure the changes meet conventions
- Open a pull request
- When the pull request merges, the [post-k8sio-groups] job will deploy the changes

## Manual deploy

- Must be run by someone who is a member of the k8s-infra-group-admins@kubernetes.io group
- Use `make run` to dry run the changes
- Use `make run -- --confirm` if the changes suggested in the previous step looks good

[post-k8sio-groups]: https://testgrid.k8s.io/wg-k8s-infra-k8sio#post-k8sio-groups 
