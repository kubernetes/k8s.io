# `workload-identity-serviceaccount` terraform module

This terraform module defines a GCP service account intended solely for use
by pods running in GKE clusters in a given project, running as a given K8s
service account in a given namespace.


## What This Creates

- **GCP service account** in the specified project
- **Workload Identity binding**: Authoritative IAM policy binding the K8s SA to the GCP SA


## Usage

```hcl
module "workload_identity_service_accounts" {
  for_each                                = local.workload_identity_service_accounts
  source                                  = "../modules/workload-identity-service-account"
  project_id                              = module.project.project_id
  name                                    = each.key
  description                             = each.value.description
  cluster_namespace                       = lookup(each.value, "cluster_namespace", local.pod_namespace)
  project_roles                           = lookup(each.value, "project_roles", [])
  additional_workload_identity_principals = lookup(each.value, "additional_workload_identity_principals", [])
}

```

## Terraform Documentation

| Name | Version |
| ---- | ------- |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.31.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >=6.31.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | >=6.31.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_project_iam_member.project_roles](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.serviceaccount](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_policy.serviceaccount_iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_policy) | resource |
| [google_iam_policy.workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_policy) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_workload_identity_principals"></a> [additional\_workload\_identity\_principals](#input\_additional\_workload\_identity\_principals) | A list of extra principals to grant WorkloadIdentityUser on the service account | `list(string)` | `[]` | no |
| <a name="input_cluster_namespace"></a> [cluster\_namespace](#input\_cluster\_namespace) | The namespace of the kubernetes service account that will bind to the service account, eg: my-namespace | `string` | n/a | yes |
| <a name="input_cluster_project_id"></a> [cluster\_project\_id](#input\_cluster\_project\_id) | The id of the project hosting clusters that will use the serviceaccount, eg: my-awesome-cluster-project (default: project\_id) | `string` | `""` | no |
| <a name="input_cluster_serviceaccount_name"></a> [cluster\_serviceaccount\_name](#input\_cluster\_serviceaccount\_name) | The name of the kubernetes service account that will bind to the service account, eg: my-cluster-sa (default: name) | `string` | `""` | no |
| <a name="input_description"></a> [description](#input\_description) | The description of the service account, eg: My Awesome Service Account (default: name) | `string` | `""` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the serviceaccount, eg: my-awesome-sa | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The id of the project hosting the serviceaccount, eg: my-awesome-project | `string` | n/a | yes |
| <a name="input_project_roles"></a> [project\_roles](#input\_project\_roles) | A list of roles to bind to the serviceaccount in its project, eg: [ "roles/bigquery.user" ] | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_email"></a> [email](#output\_email) | The email of the serviceaccount that was created |
| <a name="output_iam_policy"></a> [iam\_policy](#output\_iam\_policy) | The serviceaccount iam\_policy |
