terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>5.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.2.0"
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
    key_vault {
      purge_soft_delete_on_destroy = true # with this enabled before it deletes the key it is going to perform the purge operation over the key
    }
  }
  #   subscription_id = "00000000-0000-0000-0000-000000000000" # use az account show to grab this, otherwise do it using env variable
}
# export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" 