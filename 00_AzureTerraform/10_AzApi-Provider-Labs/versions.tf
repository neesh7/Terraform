terraform {
  required_providers {
    azapi = {
        source = "azure/azapi"
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
provider "azapi" {

}
