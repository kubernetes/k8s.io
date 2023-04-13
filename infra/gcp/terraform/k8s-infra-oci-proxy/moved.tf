/*
Copyright 2023 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/*
Copyright 2023 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// All of the variables below were moved when refactoring to a common
// module between prod and staging

/* we have to do this once per region ... */

moved {
  from = google_cloud_run_service.regions["asia-east1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["asia-east1"]
}

moved {
  from = google_cloud_run_service.regions["asia-northeast1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["asia-northeast1"]
}

moved {
  from = google_cloud_run_service.regions["asia-northeast2"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["asia-northeast2"]
}

moved {
  from = google_cloud_run_service.regions["asia-south1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["asia-south1"]
}

moved {
  from = google_cloud_run_service.regions["europe-north1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["europe-north1"]
}

moved {
  from = google_cloud_run_service.regions["europe-southwest1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["europe-southwest1"]
}

moved {
  from = google_cloud_run_service.regions["europe-west1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["europe-west1"]
}

moved {
  from = google_cloud_run_service.regions["europe-west2"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["europe-west2"]
}

moved {
  from = google_cloud_run_service.regions["europe-west4"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["europe-west4"]
}

moved {
  from = google_cloud_run_service.regions["europe-west8"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["europe-west8"]
}

moved {
  from = google_cloud_run_service.regions["europe-west9"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["europe-west9"]
}

moved {
  from = google_cloud_run_service.regions["southamerica-west1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["southamerica-west1"]
}

moved {
  from = google_cloud_run_service.regions["us-central1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["us-central1"]
}

moved {
  from = google_cloud_run_service.regions["us-east1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["us-east1"]
}

moved {
  from = google_cloud_run_service.regions["us-east4"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["us-east4"]
}

moved {
  from = google_cloud_run_service.regions["us-east5"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["us-east5"]
}

moved {
  from = google_cloud_run_service.regions["us-south1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["us-south1"]
}

moved {
  from = google_cloud_run_service.regions["us-west1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["us-west1"]
}

moved {
  from = google_cloud_run_service.regions["us-west2"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["us-west2"]
}

moved {
  from = google_cloud_run_service.regions["australia-southeast1"]
  to   = module.oci-proxy.google_cloud_run_service.oci-proxy["australia-southeast1"]
}

/* again but for iam */

moved {
  from = google_cloud_run_service_iam_member.allUsers["asia-east1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["asia-east1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["asia-northeast1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["asia-northeast1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["asia-northeast2"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["asia-northeast2"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["asia-south1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["asia-south1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["europe-north1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["europe-north1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["europe-southwest1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["europe-southwest1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["europe-west1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["europe-west1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["europe-west2"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["europe-west2"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["europe-west4"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["europe-west4"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["europe-west8"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["europe-west8"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["europe-west9"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["europe-west9"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["southamerica-west1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["southamerica-west1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["us-central1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["us-central1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["us-east1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["us-east1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["us-east4"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["us-east4"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["us-east5"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["us-east5"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["us-south1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["us-south1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["us-west1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["us-west1"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["us-west2"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["us-west2"]
}

moved {
  from = google_cloud_run_service_iam_member.allUsers["australia-southeast1"]
  to   = module.oci-proxy.google_cloud_run_service_iam_member.allUsers["australia-southeast1"]
}

/* again but for network endpoint groups */

moved {
  from = google_compute_region_network_endpoint_group.default["asia-east1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["asia-east1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["asia-northeast1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["asia-northeast1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["asia-northeast2"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["asia-northeast2"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["asia-south1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["asia-south1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["europe-north1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["europe-north1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["europe-southwest1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["europe-southwest1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["europe-west1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["europe-west1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["europe-west2"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["europe-west2"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["europe-west4"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["europe-west4"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["europe-west8"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["europe-west8"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["europe-west9"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["europe-west9"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["southamerica-west1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["southamerica-west1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["us-central1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["us-central1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["us-east1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["us-east1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["us-east4"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["us-east4"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["us-east5"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["us-east5"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["us-south1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["us-south1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["us-west1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["us-west1"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["us-west2"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["us-west2"]
}

moved {
  from = google_compute_region_network_endpoint_group.default["australia-southeast1"]
  to   = module.oci-proxy.google_compute_region_network_endpoint_group.oci-proxy["australia-southeast1"]
}



moved {
  from = google_compute_security_policy.cloud-armor
  to   = module.oci-proxy.google_compute_security_policy.cloud-armor
}

moved {
  from = google_project_iam_member.k8s_infra_oci_proxy_admins
  to   = module.oci-proxy.google_project_iam_member.k8s_infra_oci_proxy_admins
}

moved {
  from = google_project_service.project["compute.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["compute.googleapis.com"]
}

moved {
  from = google_project_service.project["containerregistry.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["containerregistry.googleapis.com"]
}

moved {
  from = google_project_service.project["logging.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["logging.googleapis.com"]
}

moved {
  from = google_project_service.project["monitoring.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["monitoring.googleapis.com"]
}

moved {
  from = google_project_service.project["oslogin.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["oslogin.googleapis.com"]
}

moved {
  from = google_project_service.project["pubsub.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["pubsub.googleapis.com"]
}

moved {
  from = google_project_service.project["run.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["run.googleapis.com"]
}


moved {
  from = google_project_service.project["storage-component.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["storage-component.googleapis.com"]
}

moved {
  from = google_project_service.project["storage-api.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["storage-api.googleapis.com"]
}

moved {
  from = google_project_service.project["storage-component.googleapis.com"]
  to   = module.oci-proxy.google_project_service.project["storage-component.googleapis.com"]
}

moved {
  from = google_project.project
  to   = module.oci-proxy.google_project.project
}

moved {
  from = google_service_account.oci-proxy
  to   = module.oci-proxy.google_service_account.oci-proxy
}

moved {
  from = google_monitoring_notification_channel.emails
  to   = module.oci-proxy.google_monitoring_notification_channel.emails
}

moved {
  from = module.alerts.google_monitoring_alert_policy.ssl_cert_expiration_alert
  to   = module.oci-proxy.module.alerts.google_monitoring_alert_policy.ssl_cert_expiration_alert
}

moved {
  from = module.alerts.google_monitoring_uptime_check_config.uptime_check
  to   = module.oci-proxy.module.alerts.google_monitoring_uptime_check_config.uptime_check
}

moved {
  from = module.alerts.google_monitoring_alert_policy.uptime_alert
  to   = module.oci-proxy.module.alerts.google_monitoring_alert_policy.uptime_alert
}

moved {
  from = module.lb-http.google_compute_backend_service.default["default"]
  to   = module.oci-proxy.module.lb-http.google_compute_backend_service.default["default"]
}

moved {
  from = module.lb-http.google_compute_global_forwarding_rule.http[0]
  to   = module.oci-proxy.module.lb-http.google_compute_global_forwarding_rule.http[0]
}

moved {
  from = module.lb-http.google_compute_global_forwarding_rule.http_ipv6[0]
  to   = module.oci-proxy.module.lb-http.google_compute_global_forwarding_rule.http_ipv6[0]
}

moved {
  from = module.lb-http.google_compute_global_forwarding_rule.https[0]
  to   = module.oci-proxy.module.lb-http.google_compute_global_forwarding_rule.https[0]
}

moved {
  from = module.lb-http.google_compute_global_forwarding_rule.https_ipv6[0]
  to   = module.oci-proxy.module.lb-http.google_compute_global_forwarding_rule.https_ipv6[0]
}

moved {
  from = module.lb-http.google_compute_managed_ssl_certificate.default[0]
  to   = module.oci-proxy.module.lb-http.google_compute_managed_ssl_certificate.default[0]
}

moved {
  from = module.lb-http.google_compute_target_http_proxy.default[0]
  to   = module.oci-proxy.module.lb-http.google_compute_target_http_proxy.default[0]
}

moved {
  from = module.lb-http.google_compute_target_https_proxy.default[0]
  to   = module.oci-proxy.module.lb-http.google_compute_target_https_proxy.default[0]
}

moved {
  from = module.lb-http.google_compute_url_map.default[0]
  to   = module.oci-proxy.module.lb-http.google_compute_url_map.default[0]
}

moved {
  from = module.lb-http.google_compute_url_map.https_redirect[0]
  to   = module.oci-proxy.module.lb-http.google_compute_url_map.https_redirect[0]
}

moved {
  from = module.lb-http.random_id.certificate[0]
  to   = module.oci-proxy.module.lb-http.random_id.certificate[0]
}

moved {
  from = google_compute_global_address.default_ipv4
  to   = module.oci-proxy.google_compute_global_address.default_ipv4
}

moved {
  from = google_compute_global_address.default_ipv6
  to   = module.oci-proxy.google_compute_global_address.default_ipv6
}
