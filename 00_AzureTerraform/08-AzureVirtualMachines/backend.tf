terraform {
# Backend is responsible for storing terraform remote state
  backend "azurerm" {
    resource_group_name = "rg-tfstate-dev"
    storage_account_name = "stfxnuyvwhjs"
    container_name =  "tfstate"
    key = "devops-dev"
  }
}