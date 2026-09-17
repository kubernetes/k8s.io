# `gke-cluster` terraform module

This terraform module defines a GKE cluster following sig-k8s-infra conventions:
- GCP Service Account for nodes
- BigQuery dataset for usage metering
- GKE cluster with some useful defaults
- No nodes are provided, they are expected to come from nodepools created via the [`gke-nodepool`] module

It is assumed the GCP project for this cluster has been created via the [`gke-project`] module

If this is a "prod" cluster:
- the BigQuery dataset will NOT be deleted on `terraform destroy`
- the GKE cluster will NOT be deleted on `terraform destroy`

[`gke-project`]: /infra/gcp/terraform/modules/gke-project
[`gke-nodepool`]: /infra/gcp/terraform/modules/gke-nodepool


## Usage

```hcl
module "prow_build_cluster" {
  source             = "../modules/gke-cluster"
  project_name       = module.project.project_id
  cluster_name       = "prow-build"
  cluster_location   = "us-central1"
  bigquery_location  = "US"
  is_prod_cluster    = "true"
  release_channel    = "REGULAR"
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
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | >=6.31.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google-beta_google_container_cluster.prod_cluster](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_container_cluster) | resource |
| [google-beta_google_container_cluster.test_cluster](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_container_cluster) | resource |
| [google_bigquery_dataset.prod_usage_metering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset) | resource |
| [google_bigquery_dataset.test_usage_metering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset) | resource |
| [google_project_iam_member.cluster_node_sa_logging](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cluster_node_sa_monitoring_metricwriter](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cluster_node_sa_monitoring_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.cluster_node_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bigquery_location"></a> [bigquery\_location](#input\_bigquery\_location) | The bigquery specific location where the dataset should be created | `string` | n/a | yes |
| <a name="input_cloud_shell_access"></a> [cloud\_shell\_access](#input\_cloud\_shell\_access) | Control plane access restricted to Google Cloud Shell | `bool` | `true` | no |
| <a name="input_cluster_location"></a> [cluster\_location](#input\_cluster\_location) | The GCP location (region or zone) where the cluster should be created | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the cluster | `string` | n/a | yes |
| <a name="input_dns_cache_enabled"></a> [dns\_cache\_enabled](#input\_dns\_cache\_enabled) | Whether the cluster has the NodeLocal DNSCache add-on enabled<br/><br/>  NOTE: changes to this value require node recreation to take effect (will happen during next maintenance window, or if gcloud command is used)<br/><br/>  More information available here: https://cloud.google.com/kubernetes-engine/docs/how-to/nodelocal-dns-cache | `string` | `"false"` | no |
| <a name="input_enable_shielded_nodes"></a> [enable\_shielded\_nodes](#input\_enable\_shielded\_nodes) | Enable Shielded Nodes on all nodes in this cluster. | `bool` | `false` | no |
| <a name="input_is_prod_cluster"></a> [is\_prod\_cluster](#input\_is\_prod\_cluster) | If this is not a prod cluster it's safe to delete resources on destroy | `string` | `"false"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the project in which to provision resources. | `string` | n/a | yes |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | The release channel of this cluster. Accepted values are `UNSPECIFIED`, `RAPID`, `REGULAR` and `STABLE`.<br/><br/>  Setting a release channel overrides the 'min\_master\_version' option.<br/><br/>  More information about release channels can be found here : https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels. | `string` | `"UNSPECIFIED"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster"></a> [cluster](#output\_cluster) | The cluster |
| <a name="output_cluster_node_sa"></a> [cluster\_node\_sa](#output\_cluster\_node\_sa) | The service\_account created for the cluster's nodes |
