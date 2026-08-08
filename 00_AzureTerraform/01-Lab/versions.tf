terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0" # basically we can have similar or a better patch of same release
      # version = "= 3.6.3" Strictly locks the version
      # version = ">= 3.6.3" It's a greater version check
    }
  }
}

# if error comes that version mismatch use terraform init -upgrade