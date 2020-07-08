/*
Ensure google groups defined in 'members' have read-only access to
all monitoring data and configurations.
Detailed list of permissions: https://cloud.google.com/monitoring/access-control#roles
*/
resource "google_project_iam_binding" "readonlymonitoringbinding" {
  project = data.google_project.project.id
  role    = "roles/monitoring.viewer"

  members = [
    "group:gke-security-groups@kubernetes.io",
  ]
}

/*
Ensure google groups defined in 'members' have read-only access to logs.
Detailed list of permissions: https://cloud.google.com/logging/docs/access-control#permissions_and_roles
*/
resource "google_project_iam_binding" "readonlyloggingbinding" {
  project = data.google_project.project.id
  role    = "roles/logging.privateLogViewer"

  members = [
    "group:gke-security-groups@kubernetes.io",
  ]
}
