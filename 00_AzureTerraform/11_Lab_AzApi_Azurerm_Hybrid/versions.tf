terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>5.0.0"
    }
    # azapi is used only for properties azurerm doesn't expose - see the VM section in main.tf
    azapi = {
      source  = "azure/azapi"
      version = "~>2.3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.4.0"
    }
  }
}
# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
  }
}
