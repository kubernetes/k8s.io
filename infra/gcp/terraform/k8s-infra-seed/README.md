# k8s-infra-seed Terraform Layer

This Terraform layer defines the k8s-infra-seed GCP project and the organization-level configuration for the `kubernetes.io` GCP org.

## What it Manages

- **Organization-level IAM**: Authoritative bindings covering org admins, billing, folder management, org policy, auditing, security center, and more.
- **Atlantis service account** (`atlantis@k8s-infra-seed.iam.gserviceaccount.com`): Identity used by Atlantis for all Terraform operations, with Workload Identity binding to the Prow cluster.
- **Datadog service account** (`datadog@k8s-infra-seed.iam.gserviceaccount.com`): Monitoring integration with read-only org-level access and token creator bindings for Datadog's GCI pipeline.



## Terraform Documentation

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | 1.10.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | 6.26.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | 6.26.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 6.26.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_iam"></a> [iam](#module\_iam) | terraform-google-modules/iam/google//modules/organizations_iam | ~> 8.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_service_account.atlantis](https://registry.terraform.io/providers/hashicorp/google/6.26.0/docs/resources/service_account) | resource |
| [google_service_account.datadog](https://registry.terraform.io/providers/hashicorp/google/6.26.0/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.atlantis](https://registry.terraform.io/providers/hashicorp/google/6.26.0/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.datadog](https://registry.terraform.io/providers/hashicorp/google/6.26.0/docs/resources/service_account_iam_binding) | resource |
| [google_organization.org](https://registry.terraform.io/providers/hashicorp/google/6.26.0/docs/data-sources/organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_seed_project_id"></a> [seed\_project\_id](#input\_seed\_project\_id) | The ID of the seed project. | `string` | n/a | yes |

## Outputs

No outputs.
