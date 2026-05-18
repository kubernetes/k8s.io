# k8s-infra-prow-build

This directory creates the GCP project and GKE cluster where Prow dispatches the majority of CI test jobs.

## What This Manages

- **GCP Project** (`k8s-infra-prow-build`): via the `gke-project` module.
- **GKE cluster** (`prow-build`): via the `gke-cluster` module, production cluster on the REGULAR release channel.
- **Node pools**: Setup via the `gke-nodepool` module.
- **Workload Identity Federation pools**: Cross-cloud authentication for EKS, Kops, and AKS build clusters.
- **VPC peering**: With GCVE (`broadcom-451918`) for vSphere testing.
- **Service accounts**: Workload Identity-bound SAs for `prow-build`, `boskos-janitor`, and `kubernetes-external-secrets`.
- **Scale test resources**: Dedicated SA and Secret Manager secret for 5k scale test cache pulling.
- **Secret Manager secrets**: CI secrets (SSH keys, service account credentials, Lambda AI API key) with group-based admin bindings.
- **External IPs**: Static addresses for Boskos metrics, external-secrets metrics, and Grafana ingress.
- **Monitoring dashboards**: Cloud Monitoring dashboards loaded from JSON definitions.

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.6 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.7.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 7.7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | ~> 7.7.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_iam"></a> [iam](#module\_iam) | terraform-google-modules/iam/google//modules/projects_iam | ~> 8.1 |
| <a name="module_project"></a> [project](#module\_project) | ../modules/gke-project | n/a |
| <a name="module_prow_build_cluster"></a> [prow\_build\_cluster](#module\_prow\_build\_cluster) | ../modules/gke-cluster | n/a |
| <a name="module_prow_build_nodepool_c4_highmem_8_localssd"></a> [prow\_build\_nodepool\_c4\_highmem\_8\_localssd](#module\_prow\_build\_nodepool\_c4\_highmem\_8\_localssd) | ../modules/gke-nodepool | n/a |
| <a name="module_prow_build_nodepool_c4a_highmem_8_localssd"></a> [prow\_build\_nodepool\_c4a\_highmem\_8\_localssd](#module\_prow\_build\_nodepool\_c4a\_highmem\_8\_localssd) | ../modules/gke-nodepool | n/a |
| <a name="module_prow_build_nodepool_c4d_highmem_8_localssd"></a> [prow\_build\_nodepool\_c4d\_highmem\_8\_localssd](#module\_prow\_build\_nodepool\_c4d\_highmem\_8\_localssd) | ../modules/gke-nodepool | n/a |
| <a name="module_workload_identity_service_accounts"></a> [workload\_identity\_service\_accounts](#module\_workload\_identity\_service\_accounts) | ../modules/workload-identity-service-account | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_address.boskos_metrics](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_address.kubernetes_external_secrets_metrics](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_global_address.grafana_ingress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_iam_workload_identity_pool.aks_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool.eks_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.aks_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_iam_workload_identity_pool_provider.eks_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_iam_workload_identity_pool_provider.eks_kops](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_monitoring_dashboard.dashboards](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_dashboard) | resource |
| [google_project_iam_member.k8s_infra_prow_oncall](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.k8s_infra_prow_viewers](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_secret_manager_secret.build_cluster_secrets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.scale_cache_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_iam_binding.build_cluster_secret_admins](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_binding) | resource |
| [google_secret_manager_secret_version.scale_cache_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_service_account.scale_cache](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_key.scale_cache](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |
| [google_vmwareengine_network_peering.gvce_peering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vmwareengine_network_peering) | resource |
| [google_iam_role.prow_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_role) | data source |
| [google_organization.org](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/organization) | data source |

## Inputs

No inputs.

## Outputs

No outputs.