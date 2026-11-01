terraform {
  required_providers {
    local = {
        source = "hashicorp/local"
        version = "1.2.0"
        # version = "~>1.2"
        # version = "<1.2.0"
        # version = "> 1.2.0"
        # version = "!= 1.2.0"
        # By combining all the expressions
        # version = ">1.2.0, <2.0.0, !=1.4.0"
    }
  }
}

# This is the resource we want to create using local provider but with a specific version
resource "local_file" "pet" {
  filename = "/root/pet.txt"
  content = "We love Pets"
}