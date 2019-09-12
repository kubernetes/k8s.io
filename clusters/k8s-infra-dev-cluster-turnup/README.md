# k8s-infra-dev-cluster-turnup

This is a Terraform configuration for the above project.

Prerequisites:
- Have GCP access to `k8s-infra-dev-cluster-turnup`

Instructions:
- Ensure you are logged into your GCP account with `gcloud auth application-default login`
- `terraform plan` will print changes needed to create cluster
- `terraform apply` will apply them
- `terraform destroy` will destroy and clean up all created resources
