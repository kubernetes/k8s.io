# k8s-infra-prow

This directory defines the GCP project and infrastructure for the Prow CI control plane. It provisions two GKE clusters, a shared VPC, static IP addresses, GCS buckets for CI and TestGrid data, TLS certificates, an Artifact Registry for Prow images, Workload Identity pools for external build clusters (IBM, AKS), and Pub/Sub for TestGrid and Kettle log ingestion.

## What This Manages

- **GCP Project** (`k8s-infra-prow`): The project that hosts the Prow control plane and utility clusters.
- **Two GKE clusters**:
  - `prow`: runs the CI control plane (hook, deck, tide, sinker, crier, etc.).
  - `utility`: runs support services (Atlantis, ArgoCD, Istio, cert-manager).
- **VPC**: Dual-stack (IPv4/IPv6) network with Cloud NAT and secondary ranges for both clusters.
- **Static IP addresses**: Global IPv4/IPv6 for Prow ingress, regional IPs for the utility cluster ingress, and NAT IPs.
- **GCS buckets**:
  - `kubernetes-ci-logs`: Public CI logs (90-day retention).
  - `k8s-security-ci-logs`: Private CI logs for kubernetes-security org jobs (14-day retention).
  - `k8s-testgrid-config` / `k8s-testgrid-config-external`: TestGrid configuration storage.
  - `k8s-infra-prow-gcb`: Cloud Build artifacts (7-day retention).
- **TLS certificates**: Managed certificates for `prow.k8s.io` and `*.prow.k8s.io`.
- **Artifact Registry**: Docker repository for Prow container images (public read).
- **Workload Identity pools**: Federation for IBM (ppc64le, s390x) and AKS external build clusters.
- **Pub/Sub**: Topic on `kubernetes-ci-logs` for TestGrid and Kettle log ingestion.

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | 1.10.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.45.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 6.45.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | ~> 6.45.0 |
| <a name="provider_http"></a> [http](#provider\_http) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_gcb_bucket"></a> [gcb\_bucket](#module\_gcb\_bucket) | terraform-google-modules/cloud-storage/google//modules/simple_bucket | ~> 11.1 |
| <a name="module_iam"></a> [iam](#module\_iam) | terraform-google-modules/iam/google//modules/projects_iam | ~> 7 |
| <a name="module_nat"></a> [nat](#module\_nat) | terraform-google-modules/cloud-nat/google | ~> 5.0 |
| <a name="module_project"></a> [project](#module\_project) | terraform-google-modules/project-factory/google | ~> 18.0 |
| <a name="module_prow"></a> [prow](#module\_prow) | terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster | ~> 37.1 |
| <a name="module_prow_bucket"></a> [prow\_bucket](#module\_prow\_bucket) | terraform-google-modules/cloud-storage/google//modules/simple_bucket | ~> 11.1 |
| <a name="module_prow_security_bucket"></a> [prow\_security\_bucket](#module\_prow\_security\_bucket) | terraform-google-modules/cloud-storage/google//modules/simple_bucket | ~> 11.1 |
| <a name="module_testgrid_config_bucket"></a> [testgrid\_config\_bucket](#module\_testgrid\_config\_bucket) | github.com/terraform-google-modules/terraform-google-cloud-storage//modules/simple_bucket | v11.1.2 |
| <a name="module_testgrid_config_external_bucket"></a> [testgrid\_config\_external\_bucket](#module\_testgrid\_config\_external\_bucket) | terraform-google-modules/cloud-storage/google//modules/simple_bucket | ~> 12.1 |
| <a name="module_utility_cluster"></a> [utility\_cluster](#module\_utility\_cluster) | terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster | ~> 37.1 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-google-modules/network/google | ~> 11.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_artifact_registry_repository.images](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_artifact_registry_repository_iam_member.image_builder](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_artifact_registry_repository_iam_member.images](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_certificate_manager_certificate.prow](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_certificate) | resource |
| [google_certificate_manager_certificate_map.prow](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_certificate_map) | resource |
| [google_certificate_manager_certificate_map_entry.prow](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_certificate_map_entry) | resource |
| [google_certificate_manager_dns_authorization.prow](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_dns_authorization) | resource |
| [google_compute_address.prow_nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_address.utility_ingress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_global_address.prow](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_iam_workload_identity_pool.ibm_clusters](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.ppc64le](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_iam_workload_identity_pool_provider.s390x](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_pubsub_topic.kubernetes_ci_logs_topic](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_binding.publish_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_binding) | resource |
| [google_pubsub_topic_iam_binding.read_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_binding) | resource |
| [google_service_account.argocd](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.image_builder](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.prow](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.argocd](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.prow](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_member.image_builder](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_notification.notification](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_notification) | resource |
| [google_storage_project_service_account.gcs_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |
| [http_http.ppc64le_issuer](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.ppc64le_jwks](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.s390x_issuer](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.s390x_jwks](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
