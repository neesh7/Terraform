terraform {
  required_version = "~>1.15.0"

  # Connects this config to HCP Terraform (state + runs live in the workspace below)
  cloud {
    organization = "neesh7-org1"

    workspaces {
      name = "neesh7-dev"
    }
  }

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "local" {}
