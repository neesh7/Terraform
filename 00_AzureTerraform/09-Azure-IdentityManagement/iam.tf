data "azuread_client_config" "current" {}

resource "azuread_group" "remote_access_users" {
  display_name     = "${var.application_name}-${var.environment_name}-remote-access-user"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azuread_group_member" "Neesh_remote_access_membership" {
  group_object_id  = azuread_group.remote_access_users.object_id
  member_object_id = data.azuread_client_config.current.object_id
}