terraform {
  required_version = "~>1.15.0"

  cloud {

    organization = "neesh7-org1"

    workspaces {
      name = "neesh7-dev"
    }
  }
}