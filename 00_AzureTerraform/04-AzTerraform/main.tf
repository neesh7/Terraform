resource "azurerm_resource_group" "main" {
  # following a proper naming convention
  name = "rg-${var.application_name}-${var.environment_name}"
  location = var.primary_location
}
# terraform apply -var-file ./env/dev.tfvars 
resource "random_string" "random_string_suffix" {
    length = 10
    upper = false
    special = false
}
resource "azurerm_storage_account" "main" {
  name                     = "st${random_string.random_string_suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "staging"
  }
}
# terraform workspace new dev
# terraform workspace list
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "tfstatefile" {
  name                 = "tfstate"
  storage_container_id = azurerm_storage_container.tfstate.id
  type                 = "Block"
  source               = "terraform.tfstate"
}