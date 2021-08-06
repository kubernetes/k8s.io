# terraform

This directory contains Terraform modules and configurations for some of the
GCP projects maintained by wg-k8s-infra.

## Layout

```
.
├── modules           # modules inteded for re-use in-repo
│   └── <module>      # a reusable group of terraform resources 
└── <project>         # module scoped to terraform resources within GCP project <project> (.tf files live here)
    └── <cluster>     # GKE cluster named <cluster> for each cluster in the project
        └── resources # cluster-scoped k8s resources live in resources
            └── <ns>  # namespace-scoped k8s resources live in <namespace>
```

Each directory in `modules` represents a Terraform module intended for reuse
inside of this repo. Not every configuration is able to use these modules yet
due to differences in google provider version.

Each directory in `projects` represents a GCP project. Those that have GKE
clusters have a subdirectory per cluster which may contain a resources folder
containing manifests that are deployed to the cluster

## Prerequsites

- The specific privileges required for each module may be different, but the
  intent is for each project module to be deployable by anyone with `roles/owner`
  for the project, via membership in the appropriate groups:

  - k8s-infra-ii-sandbox: k8s-infra-ii-coop@kubernetes.io
  - k8s-infra-prow-build: k8s-infra-prow-oncall@kubernetes.io
  - k8s-infra-prow-build-trusted: k8s-infra-prow-oncall@kubernetes.io
  - kubernetes-public: k8s-infra-gcp-org-admins@kubernetes.io
  - k8s-infra-public-pii: k8s-infra-gcp-org-admins@kubernetes.io

- `tfswitch` is installed: https://tfswitch.warrensbox.com/Install/
- `terraform` is installed: `tfswitch` in the module which is being managed

## Developing

- From within a module directory:
- `tfswitch` will ensure the correct version of terraform is used 
- `terraform fmt` will auto-format all `.tf` files
- `terraform validate` will validate that all `.tf` files are valid 

## Deploying

- Ensure you are logged into your GCP account with `gcloud auth application-default login`
- From within a module directory:
  - `terraform init` will initialize your local state (refresh modules)
  - `terraform plan` will print changes needed to create/update a cluster
  - `terraform apply` will apply them

## Deleting

- Get approval from a WG K8s Infra lead (ask in [#wg-k8s-infra] before doing this)
- Ensure you are logged into your GCP account with `gcloud auth application-default login`
- From within a module directory:
  - `terraform destroy` will destroy and clean up all created resources

[#wg-k8s-infra]: https://kubernetes.slack.com/messages/wg-k8s-infra
