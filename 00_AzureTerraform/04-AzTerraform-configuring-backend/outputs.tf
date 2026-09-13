# Values needed to configure the azurerm backend in downstream configs
# (e.g. ../05-Lab-RemoteState-backend/versions.tf)

output "backend_resource_group_name" {
  description = "resource_group_name for the azurerm backend block"
  value       = azurerm_resource_group.main.name
}

output "backend_storage_account_name" {
  description = "storage_account_name for the azurerm backend block"
  value       = azurerm_storage_account.main.name
}

output "backend_container_name" {
  description = "container_name for the azurerm backend block"
  value       = azurerm_storage_container.tfstate.name
}
