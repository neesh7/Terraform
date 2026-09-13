# Step 1 - Creating resource group using terraform over Azure
resource "azurerm_resource_group" "main" {
  # following a proper naming convention
  # name = "rg-foobar"
  name = "rg-${var.application_name}-${var.environment_name}" # environment name will flow here from env/dev.tfvars or env/prod.tfvars
  location = var.primary_location
}
# terraform apply -var-file ./env/dev.tfvars

# Stept 2.1: Generating random string to use in naming of resources
resource "random_string" "random_string_suffix" {
    length = 10
    upper = false
    special = false
}

# Step 2: Setting up storage account
resource "azurerm_storage_account" "main" {
  name                     = "st${random_string.random_string_suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "staging"
  }
  # No depends_on needed: name references random_string_suffix.result above,
  # which is an implicit dependency Terraform already orders correctly.
}
# terraform workspace new dev
# terraform workspace list

# Step 3 - Setting up blob container because we need this to store our tfstate files
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
# Note : use right resource Abbreviation to name your azure resources
# The state blob itself is NOT created here — the azurerm backend in downstream
# configs creates and manages it via the `key` value. Uploading terraform.tfstate
# as a blob from this config is circular and locks against the running apply.