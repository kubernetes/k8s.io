# `gke-nodepool` terraform module

This terraform module defines a GKE nodepool following sig-k8s-infra conventions, including:
- Workload Identity is enabled by default for this nodepool
- Legacy metadata endpoints are disabled
- Auto-repair and auto-upgrade are enabled

It is assumed that the associated GKE cluster has been provisioned using the [`gke-cluster`] module

[`gke-cluster`]: /infra/gcp/terraform/modules/gke-cluster
[`gke-project`]: /infra/gcp/terraform/modules/gke-project


## Usage

```hcl
module "prow_build_nodepool_c4_highmem_8_localssd" {
  source       = "../modules/gke-nodepool"
  project_name = module.project.project_id
  cluster_name = module.prow_build_cluster.cluster.name
  location     = module.prow_build_cluster.cluster.location
  node_locations = [
    "us-central1-a",
    "us-central1-b",
    "us-central1-c",
    "us-central1-f",
  ]
  name                         = "pool6"
  initial_count                = 1
  min_count                    = 1
  max_count                    = 250 # total across all zones
  machine_type                 = "c4-highmem-8-lssd"
  disk_size_gb                 = 100
  disk_type                    = "hyperdisk-balanced"
  enable_nested_virtualization = true
  service_account              = module.prow_build_cluster.cluster_node_sa.email
  taints = [
    {
      key    = "spare"
      value  = "true"
      effect = "PREFER_NO_SCHEDULE"
    }
  ]
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
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | >=6.31.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google-beta_google_container_node_pool.node_pool](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_container_node_pool) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the cluster to attach this node\_pool to | `string` | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | The disk\_size\_gb of this node\_pool | `string` | n/a | yes |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | The disk\_type of this node\_pool | `string` | n/a | yes |
| <a name="input_enable_nested_virtualization"></a> [enable\_nested\_virtualization](#input\_enable\_nested\_virtualization) | Whether to enable nested virtualization on the node pool's VMs | `bool` | `false` | no |
| <a name="input_ephemeral_local_ssd_count"></a> [ephemeral\_local\_ssd\_count](#input\_ephemeral\_local\_ssd\_count) | Number of local SSDs to provision for ephemeral storage. If 0, ephemeral storage is backed by boot disk | `string` | `0` | no |
| <a name="input_image_type"></a> [image\_type](#input\_image\_type) | The image\_type of this node\_pool | `string` | `"COS_CONTAINERD"` | no |
| <a name="input_initial_count"></a> [initial\_count](#input\_initial\_count) | The initial\_node\_count of this node\_pool | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | The labels to apply to this node\_pool | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | The GCP location (region or zone) where the node\_pool should be located | `string` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine\_type of this node\_pool | `string` | n/a | yes |
| <a name="input_max_count"></a> [max\_count](#input\_max\_count) | The max\_node\_count of this node\_pool | `string` | n/a | yes |
| <a name="input_min_count"></a> [min\_count](#input\_min\_count) | The min\_node\_count of this node\_pool | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The name to use for this node\_pool | `string` | n/a | yes |
| <a name="input_node_locations"></a> [node\_locations](#input\_node\_locations) | The GCP locations (regions or zones) where the node\_pool should be located | `list(any)` | `[]` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the project in which to provision the node\_pool | `string` | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | The email address of the GCP Service Account to be associated with nodes in this node\_pool | `string` | n/a | yes |
| <a name="input_taints"></a> [taints](#input\_taints) | The taints to apply to this node\_pool upon creation (NOTE: changes will be ignored throughout lifecycle) | `list(object({ key = string, value = string, effect = string }))` | `[]` | no |

## Outputs

No outputs.
