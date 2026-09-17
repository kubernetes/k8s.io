# `gke-project` terraform module

This terraform module defines a GCP project following sig-k8s-infra conventions
that is intended to host a GKE cluster created by the [`gke-cluster`] module:
- Project is associated with CNCF org
- Project is linked to CNCF billing account
- Services necessary to support [`gke-cluster`] are enabled
- Some default IAM bindings are added:
  - k8s-infra-cluster-admins@ gets `roles/compute.viewer`, `roles/container.admin`, org role [`ServiceAccountLister`]
  - gke-security-groups@ gets `roles/container.clusterViewer`

[`gke-cluster`]: /infra/gcp/terraform/modules/gke-cluster
[`gke-nodepool`]: /infra/gcp/terraform/modules/gke-nodepool
[`ServiceAccountLister`]: /infra/gcp/roles/iam.serviceAccountLister.yaml

## Usage

```hcl
module "project" {
  source       = "../modules/gke-project"
  project_id   = "k8s-infra-prow-build"
  project_name = "k8s-infra-prow-build"
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
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_iam_member.cluster_admins](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cluster_users](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_iam_role.service_account_lister](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_role) | data source |
| [google_organization.org](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_admins_group"></a> [cluster\_admins\_group](#input\_cluster\_admins\_group) | The group to treat as cluster admins | `string` | `"k8s-infra-cluster-admins@kubernetes.io"` | no |
| <a name="input_cluster_users_group"></a> [cluster\_users\_group](#input\_cluster\_users\_group) | The group to treat as cluster users | `string` | `"gke-security-groups@kubernetes.io"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The id of the project, eg: my-awesome-project | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The display name of the project, eg: My Awesome Project | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The project\_id of the project that was created |
| <a name="output_project_number"></a> [project\_number](#output\_project\_number) | Numeric identifier for the project |
