# oci-proxy common module

This module contains ~all of the config for oci-proxy / oci-proxy-staging.

Staging is expected to continuously lead production rollouts and changes
will be vetted in staging before manually rolling out to production.

The only differences between staging and production are inputs variables
to this module, such as domain and IP address.



## What This Creates

- **Cloud Run services**: Deployed in 10+ regions globally
- **Global external HTTPS load balancer**: Deployed with Cloud Armor security policy
- **Serverless NEGs**: Connects the load balancer to Cloud Run
- **Cloud Armor**: Security policy for DDoS protection
- **Monitoring**: Uptime checks and alert policies (via `monitoring/uptime-alert` submodule)
- **Networking**: URL map, SSL certificates, forwarding rules




## Terraform Documentation

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_alerts"></a> [alerts](#module\_alerts) | ../monitoring/uptime-alert | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [google-beta_google_compute_region_network_endpoint_group.default](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_region_network_endpoint_group) | resource |
| [google_certificate_manager_certificate.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_certificate) | resource |
| [google_certificate_manager_certificate_map.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_certificate_map) | resource |
| [google_certificate_manager_certificate_map_entry.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_certificate_map_entry) | resource |
| [google_certificate_manager_dns_authorization.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_dns_authorization) | resource |
| [google_cloud_run_service.oci-proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_service) | resource |
| [google_cloud_run_service_iam_member.allUsers](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_service_iam_member) | resource |
| [google_compute_backend_service.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_global_address.ipv4](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_address.ipv6](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.http_ipv4](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_global_forwarding_rule.http_ipv6](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_global_forwarding_rule.https_ipv4](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_global_forwarding_rule.https_ipv6](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_security_policy.cloud-armor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy) | resource |
| [google_compute_target_http_proxy.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy) | resource |
| [google_compute_target_https_proxy.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy) | resource |
| [google_compute_url_map.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_compute_url_map.https_redirect](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_monitoring_notification_channel.emails](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel) | resource |
| [google_project_iam_member.k8s_infra_oci_proxy_admins](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.oci-proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_digest"></a> [digest](#input\_digest) | this one is overridden to the latest image in staging typically | `string` | `"sha256:d91229530a784c0569adf7192978f64c9371e906ed726cc3061aa98c2706bdce"` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | these should all be explicitly set for both prod and staging | `string` | n/a | yes |
| <a name="input_notification_channel_id"></a> [notification\_channel\_id](#input\_notification\_channel\_id) | n/a | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | n/a | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | n/a | `string` | n/a | yes |
| <a name="input_verbosity"></a> [verbosity](#input\_verbosity) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_region_locations"></a> [region\_locations](#output\_region\_locations) | n/a |
| <a name="output_service_account_id"></a> [service\_account\_id](#output\_service\_account\_id) | n/a |
