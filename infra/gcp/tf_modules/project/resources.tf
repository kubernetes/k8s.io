#
# definitions
# 

locals {
    project_name    = var.project_name
    project_id      = var.project_id
    billing_account = var.billing_account
    env_name        = var.env_name
    writer          = var.writer
		enable_api      = var.enable_api
}

#
# resources
#

resource "google_project" project" {
  name       = "k8s-${local.env_name}-${local.project_name}"
  project_id = local.project_id
  billing_account = local.billing_account
}


data "google_iam_policy" "read" {
  binding {
    role = "roles/viewer"

    members = [
      "group:${local.writer}",
    ]
  }

}

resource "google_project_service" "project" {
  project = local.project_id
  service =  local.enable_api
}

