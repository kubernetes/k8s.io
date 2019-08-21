# k8s-infra-dev-cluster-turnup

This is a Terraform configuration for the above project.

Prerequisites:
- Have GCP access to `k8s-infra-dev-cluster-turnup`
- Have access to https://app.terraform.io/app/k8s-infra/workspaces

Instructions:
- Go to https://app.terraform.io/app/settings/tokens and create a user token
- Ensure there is a `.terraformrc` file in your home directory with the following format:
```
credentials "app.terraform.io" {
  token = "XXXX"
}
```
- Ensure you are logged into your GCP account with `gcloud auth application-default login`
- `terraform plan` will print changes needed to create cluster
- `terraform apply` will apply them
- `terraform destroy` will destroy and clean up all created resources
