# clusters

This directory contains Terraform modules and configurations for the various
GCP projects and Kubernetes clusters that the Kubernetes project maintains.

## Layout

```
.
├── modules
│   └── <module>
└── projects
    └── <project>
        └── <cluster>
```

Each directory in `modules` represents a Terraform module intended for reuse
inside of this repo. Not every configuration is able to use these modules yet
due to differences in google provider version.

Each directory in `projects` represents a GCP project. Each subdirectory of
those represents a GKE cluster configuration.

## Prerequsites

- Be a member of the k8s-infra-cluster-admins@kubernetes.io group.
- Have Terraform installed
  (<https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip>)

## Instructions

- Ensure you are logged into your GCP account with `gcloud auth application-default login`
- From within a cluster directory:
  - `terraform init` will initialize your local state
  - `terraform plan` will print changes needed to create/update a cluster
  - `terraform apply` will apply them
  - `terraform destroy` will destroy and clean up all created resources
