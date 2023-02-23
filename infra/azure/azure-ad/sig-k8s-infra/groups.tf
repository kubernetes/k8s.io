resource "azuread_group" "group" {
  for_each = local.groups
  display_name     = each.key
  security_enabled = true
  members = [for user in try(each.value.members, []) : data.azuread_user.main[user].object_id]
}

data "azuread_user" "main" {
  for_each = try(toset(var.users), [])
  user_principal_name = each.value
}   

locals {
  groups =  yamldecode(file("${path.module}/groups.yaml"))
}

#https://discuss.hashicorp.com/t/using-for-each-and-lookup-in-a-data-block-does-not-return-a-string/34227
