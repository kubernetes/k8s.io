locals {
  domain_name = "k8s.borg.dev"
  users       = csvdecode(file("./users.csv"))
}

resource "random_string" "random" {
  length           = 16
  special          = true
}
# Create users
resource "azuread_user" "users" {
  for_each = { for user in local.users : user.github_username => user }

  user_principal_name = format(
    "%s@%s",
    each.value.github_username,
    local.domain_name
  )

  password = uuid()
  force_password_change = true
  other_mails = [
    each.value.email
  ]
  lifecycle {
    ignore_changes = [
      password,
    ]
  }

  given_name = each.value.first_name
  surname = each.value.last_name
  usage_location = "US"

  display_name = "${each.value.first_name} ${each.value.last_name}"
}

resource "azuread_group" "aws_group" {
  # All users that need AWS access must be part of this group for provisioning to work
  display_name     = "aws-users"
  security_enabled = true
  members = values(azuread_user.users)[*].object_id
}

module "sig_k8s_infra_groups" {
  source     = "./sig-k8s-infra"
  users  = values(azuread_user.users)[*].user_principal_name
  depends_on = [azuread_user.users]
}
