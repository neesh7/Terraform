# Step 1 - Creating resource group using terraform over Azure
resource "azurerm_resource_group" "main" {
  # following a proper naming convention
  # name = "rg-foobar"
  name = "rg-${var.application_name}-${var.environment_name}" # environment name will flow here from env/dev.tfvars or env/prod.tfvars
  location = var.primary_location
}
# As this is for obeservability stack we need to use log analytics

# Step 2: Setting up azure log analytics workspace
resource "azurerm_log_analytics_workspace" "example" {
  name                = "log-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}