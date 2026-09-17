# k8s-infra-prow-build-trusted

This directory creates a smaller, dedicated GKE cluster for sensitive CI operations, Cloud Build triggers for staging projects, image promotion, jobs that require GitHub tokens, registry credentials, or other secrets.

## What This Manages

- **GCP Project** (`k8s-infra-prow-build-trusted`): via the `gke-project` module.
- **GKE cluster** (`prow-build-trusted`): via the `gke-cluster` module, production cluster on the `REGULAR` release channel.
- **Single node pool** (`trusted-pool2`): c4-highmem-8 (1–6 nodes, UBUNTU_CONTAINERD).
- **Service accounts**: Workload Identity-bound SAs for `gcb-builder`, `prow-deployer`, `k8s-cve-feed`, `k8s-keps`, `k8s-metrics`, `k8s-triage`, `k8s-testgrid-config-updater`, `kubernetes-external-secrets`, and the default `prow-build-trusted` pod SA.
- **Secret Manager secrets**: GitHub tokens, cluster kubeconfigs (EKS, Kops), registry credentials (Quay.io), service accounts, Slack auth, Snyk token, and more, with group-based admin bindings.
- **External IPs**: Static addresses for external-secrets and ghproxy metrics scraping.
- **Project-level IAM**: Authoritative bindings for cluster admin and secret access.


## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.6 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.31.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 6.31.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | ~> 6.31.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_iam"></a> [iam](#module\_iam) | terraform-google-modules/iam/google//modules/projects_iam | ~> 8.1 |
| <a name="module_project"></a> [project](#module\_project) | ../modules/gke-project | n/a |
| <a name="module_prow_build_cluster"></a> [prow\_build\_cluster](#module\_prow\_build\_cluster) | ../modules/gke-cluster | n/a |
| <a name="module_prow_build_nodepool2"></a> [prow\_build\_nodepool2](#module\_prow\_build\_nodepool2) | ../modules/gke-nodepool | n/a |
| <a name="module_workload_identity_service_accounts"></a> [workload\_identity\_service\_accounts](#module\_workload\_identity\_service\_accounts) | ../modules/workload-identity-service-account | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_address.ghproxy_metrics_address](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_address.kubernetes_external_secrets_metrics_address](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_project_iam_member.k8s_infra_prow_oncall](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_secret_manager_secret.build_cluster_secrets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_iam_binding.build_cluster_secret_admins](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_binding) | resource |
| [google_secret_manager_secret_iam_member.k8s_prow_kes_sa_role_accessor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.k8s_prow_kes_sa_role_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_organization.org](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/organization) | data source |
| [google_secret_manager_secret.capdo_quayio_registry_secret](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret) | data source |

## Inputs

No inputs.

## Outputs

No outputs.