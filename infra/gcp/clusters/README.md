# clusters

This directory contains Terraform cluster configurations for the various GCP
projects that the Kubernetes project maintains.

Each directory except `modules` represents a GCP project.  Each sub-directory of
those represents a GKE cluster configuration.  Not everything is able to use the
modules yet due to differences in google provider version. 

Prerequisites:
- Be a member of the k8s-infra-cluster-admins@kubernetes.io group.
- Have Terraform installed
  (https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip)

Instructions:
- Ensure you are logged into your GCP account with `gcloud auth application-default login`
- From within a cluster directory:
  - `terraform init` will initialize your local state
  - `terraform plan` will print changes needed to create/update a cluster
  - `terraform apply` will apply them
  - `terraform destroy` will destroy and clean up all created resources
