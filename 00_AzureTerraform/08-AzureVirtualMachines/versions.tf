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
}
# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
  }
#   subscription_id = "00000000-0000-0000-0000-000000000000" # use az account show to grab this, otherwise do it using env variable
}
# export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" 