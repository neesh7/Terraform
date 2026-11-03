terraform {
  required_version = ">= 1.6, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Authentication: Azure CLI session (az login)
# Target subscription: var.subscription_id, set in dev.tfvars
provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}
