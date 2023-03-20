resource "google_iam_deny_policy" "gcs_deny" {
  provider = google-beta
  parent   = urlencode("cloudresourcemanager.googleapis.com/projects/${google_project.project.project_id}")
  name     = "deny-pii-access-to-infra-auditors"
  display_name = "Deny GCS Data to k8s-infra-auditors"
  rules {
    description = "First rule"
    deny_rule {
      denied_principals = ["principalSet://goog/group/k8s-infra-auditors@kubernetes.io"]
      denied_permissions = [
        "storage.googleapis.com/objects.get", // Reading blobs
        ]
    }
  }
}
