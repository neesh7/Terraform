terraform {
# Backend is responsible for storing terraform remote state
  backend "azurerm" {
    resource_group_name = "rg-tfstate-dev"
    storage_account_name = "steh52icsuob"
    container_name =  "tfstate"
    key = "hybrid-dev"
  }
}