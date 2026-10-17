terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>5.0.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~>3.9.0"
    }
  }
  # Backend is responsible for storing terraform remote state
  backend "azurerm" {
    resource_group_name = "rg-tfstate-dev"
    storage_account_name = "steh52icsuob"
    container_name =  "tfstate"
    key = "devops-dev"
  }
  # if we are using shell to provide backend-config then
}
# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
#   subscription_id = "00000000-0000-0000-0000-000000000000" # use az account show to grab this, otherwise do it using env variable
}
# export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" 