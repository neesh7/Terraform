# Cerating resource group
resource "azurerm_resource_group" "main" {
  name = "rg-${var.application_name}-${var.environment_name}" # environment name will flow here from env/dev.tfvars or env/prod.tfvars
  location = var.primary_location
}
# Random string
resource "random_string" "keyvault_suffix" {
  length = 6
  upper = false
  special = false
}

# Data source
data "azurerm_client_config" "current" {}
# Configuring Azure Key Vault

resource "azurerm_key_vault" "main" {
#   name                        = "kv-${var.application_name}-${var.environment_name}"
  name                        = "kv-${var.application_name}-${var.environment_name}-${random_string.keyvault_suffix.result}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  rbac_authorization_enabled  = true
#   tenant_id                   = "ee1ef095-fc21-4d1f-8d7a-104a597df771"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name = "standard"

}
# data "azurerm_subscription" "primary" {
# }

# data "azurerm_client_config" "example" {
# }

# Doing role assignment for the key vault user
resource "azurerm_role_assignment" "terraform_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# we've already created log analytics workspace in 05-*lab we want to reuse it here
data "azurerm_log_analytics_workspace" "observability" {
  name                = "log-observability-dev"
  resource_group_name = "rg-observability-dev"
}

# Adding azure monitor resource for key vault monitoring
resource "azurerm_monitor_diagnostic_setting" "main" {
  name               = "diag-${var.application_name}-${var.environment_name}-${random_string.keyvault_suffix.result}"
  target_resource_id = azurerm_key_vault.main.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.observability.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

