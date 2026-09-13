terraform {
# Backend is responsible for storing terraform remote state
  backend "azurerm" {
    resource_group_name = "rg-tfstate-dev"
    storage_account_name = "stzg11ha9mhl"
    container_name =  "tfstate"
    key = "devops-dev"
  }
}