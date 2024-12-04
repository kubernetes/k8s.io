# terraform

This directory contains Terraform modules and configurations for some of the
GCP projects maintained by sig-k8s-infra.

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

- Open a PR and Atlantis will apply and deploy your Terraform changes.
- Ensure you are logged into your GCP account with `gcloud auth application-default login`
- From within a module directory:
  - `terraform init` will initialize your local state (refresh modules)
  - `terraform plan` will print changes needed to create/update a cluster
  - `terraform apply` will apply them

## Deleting

- Get approval from a SIG K8s Infra lead (ask in [#sig-k8s-infra] before doing this)
- Ensure you are logged into your GCP account with `gcloud auth application-default login`
- From within a module directory:
  - `terraform destroy` will destroy and clean up all created resources

[#sig-k8s-infra]: https://kubernetes.slack.com/messages/sig-k8s-infra


# Bootstrapping Terraform - One Time Setup

Terraform needs to be bootstrapped manually before it can be used. This process was done during Atlantis Setup. It is noted here for completeness and for potential troubleshooting.

This needs to be ran by a person.

```
# Get the ORG_ID
ORG_ID=$(gcloud organizations describe kubernetes.io --format json | jq .name -r | sed 's:.*/::')

# Create the k8s-infra-seed project

gcloud projects create k8s-infra-seed --organization $ORG_ID --name "K8s Infra Seed" --billing

# Create the terraform service account

gcloud iam service-accounts create atlantis —-display-name Atlantis --project k8s-infra-seed

# Allow the Atlantis Kubernetes Service Account in k8s-infra-prow project to assume this service account

gcloud iam service-accounts add-iam-policy-binding atlantis@k8s-infra-seed.iam.gserviceaccount.com \
  --member "serviceAccount:k8s-infra-prow.svc.id.goog[atlantis/atlantis]" --role='roles/iam.workloadIdentityUser'

# Create the State Bucket and version it
gcloud storage buckets create gs://k8s-infra-tf-state --location=us --uniform-bucket-level-access
gcloud storage buckets update gs://k8s-infra-tf-state --versioning

# Enable Google APIs
gcloud services enable container.googleapis.com run.googleapis.com cloudbuild.googleapis.com  --async

# Privilege the terraform service account
gcloud organizations add-iam-policy-binding --organization $ORG_ID \
  --member "serviceAccount:atlantis@k8s-infra-seed.iam.gserviceaccount.com" --role='roles/resourcemanager.organizationAdmin'
gcloud organizations add-iam-policy-binding --organization $ORG_ID \
  --member "serviceAccount:atlantis@k8s-infra-seed.iam.gserviceaccount.com" --role='roles/owner'
gcloud organizations add-iam-policy-binding --organization $ORG_ID \
  --member "serviceAccount:atlantis@k8s-infra-seed.iam.gserviceaccount.com" --role='roles/billing.admin'
```
