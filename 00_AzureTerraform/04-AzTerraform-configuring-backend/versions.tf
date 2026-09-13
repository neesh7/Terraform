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
  features {}
#   subscription_id = "355d1606-549b-4027-86d8-jkajkfsabjaf" 
# use az account show to grab this, otherwise do it using env variable
}
# export ARM_SUBSCRIPTION_ID="355d1606-549b-4027-86d8-7036748a1e32"