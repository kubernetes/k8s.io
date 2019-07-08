# Automation of Google Groups maintenance for k8s-infra permissions

- Edit groups.yaml to add a new group or update an existing group
- All groups MUST start with "k8s-infra-" prefix for the reconcile.go to work 
- Use `go run reconcile.go` to dry run the changes
- Use `go run reconcile.go --confirm` if the changes suggested in the previous step looks good

Note:
- To add new git-crypt collaborators, use the `git-crypt add-gpg-user` command. See example steps in:
  https://guyrking.com/2018/09/22/encrypt-files-with-git-crypt.html
