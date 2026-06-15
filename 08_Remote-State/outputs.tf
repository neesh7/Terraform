# Output values from the infrastructure

output "resource_group_name" {
  value       = azurerm_resource_group.app.name
  description = "Name of the resource group"
}

output "storage_account_name" {
  value       = azurerm_storage_account.app.name
  description = "Name of the storage account"
}
