module "iam" {
  source  = "terraform-google-modules/iam/google//modules/organizations_iam"
  version = "~> 8.1"

  organizations = [data.google_organization.org.org_id]

  mode = "authoritative"

  bindings = {
    "roles/owner" = [
      google_service_account.atlantis.member,
      "group:k8s-infra-gcp-org-admins@kubernetes.io",
    ]

    "roles/billing.admin" = [
      google_service_account.atlantis.member,
      "group:k8s-infra-gcp-org-admins@kubernetes.io",
      "user:twaggoner@linuxfoundation.org",
    ]
    "roles/billing.viewer" = [
      "group:k8s-infra-gcp-accounting@kubernetes.io"
    ]
    "roles/resourcemanager.organizationAdmin" = [
      "serviceAccount:atlantis@k8s-infra-seed.iam.gserviceaccount.com",
      "group:k8s-infra-gcp-org-admins@kubernetes.io",
      "user:domain-admin-lf@kubernetes.io",
    ]

    "roles/resourcemanager.folderAdmin" = [
      "group:k8s-infra-gcp-org-admins@kubernetes.io",
      google_service_account.atlantis.member,
    ]
    "roles/browser" = [
      "group:k8s-infra-prow-oncall@kubernetes.io",
      "group:gke-security-groups@kubernetes.io",
      "user:twaggoner@linuxfoundation.org",
      google_service_account.datadog.member,
    ]
    "roles/resourcemanager.projectCreator" = [
      "group:k8s-infra-gcp-org-admins@kubernetes.io",
      google_service_account.atlantis.member,
    ]
    "roles/orgpolicy.policyAdmin" = [
      "group:k8s-infra-gcp-org-admins@kubernetes.io",
      "serviceAccount:atlantis@k8s-infra-seed.iam.gserviceaccount.com",
    ]
    "roles/cloudsupport.admin" = [
      "group:k8s-infra-gcp-org-admins@kubernetes.io",
    ]

    "organizations/758905017065/roles/audit.viewer" = [
      "group:k8s-infra-gcp-auditors@kubernetes.io",
      "serviceAccount:k8s-infra-gcp-auditor@kubernetes-public.iam.gserviceaccount.com"
    ]
    "organizations/758905017065/roles/organization.admin" = [ #TODO: remove this role and use the predefined google roles
      "group:k8s-infra-gcp-org-admins@kubernetes.io"
    ]
    "roles/serviceusage.serviceUsageConsumer" = [
      google_service_account.datadog.member,
    ]
    "roles/compute.viewer" = [
      google_service_account.datadog.member,
    ]
    "roles/cloudasset.viewer" = [
      google_service_account.datadog.member,
    ]
    "roles/monitoring.viewer" = [
      google_service_account.datadog.member,
    ]
  }
}
