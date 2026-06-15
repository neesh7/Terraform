# Terraform configuration and provider setup

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Remote state backend configuration using Azure Blob Storage
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateaccount"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
