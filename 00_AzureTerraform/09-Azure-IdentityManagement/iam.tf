data "azuread_client_config" "current" {}

resource "azuread_group" "remote_access_users" {
  display_name     = "${var.application_name}-${var.environment_name}-remote-access-user"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

locals {
  remote_access_users_map = { for idx, element in var.remote_access_users: element => idx}
}
#  We are just authorizing the current memeber to be part of memebership ,
#  but the problem is if we do this it will be constantly adding and removal of user
#  so instead of this we will be using a data source to get my user id directly
data "azuread_user" "remote_access_users" {
#   count = length(var.remote_access_users)
  for_each = local.remote_access_users_map
#   user_principal_name = var.remote_access_users[count.index]
  user_principal_name = each.key
}
resource "azuread_group_member" "remote_access_users_membership" {
#   count = length(var.remote_access_users)
  for_each = local.remote_access_users_map
  group_object_id  = azuread_group.remote_access_users.object_id
#   member_object_id = data.azuread_client_config.current.object_id
#   member_object_id = data.azuread_user.remote_access_users[count.index].object_id
member_object_id = data.azuread_user.remote_access_users[each.key].object_id
}

