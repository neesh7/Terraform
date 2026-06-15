# Application infrastructure resources

# Resource Group for application resources
resource "azurerm_resource_group" "app" {
  name     = "app-rg-${var.environment}"
  location = var.location

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Storage Account for application data
resource "azurerm_storage_account" "app" {
  name                     = "appsa${var.environment}${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.app.name
  location                 = azurerm_resource_group.app.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Random suffix for storage account name uniqueness
resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}
