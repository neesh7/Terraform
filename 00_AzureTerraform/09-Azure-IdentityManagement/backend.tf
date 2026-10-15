terraform {
  # Backend is responsible for storing terraform remote state
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-dev"
    storage_account_name = "stjq47ue88ju"
    container_name       = "tfstate"
    key                  = "linuxvm-dev"
  }
}