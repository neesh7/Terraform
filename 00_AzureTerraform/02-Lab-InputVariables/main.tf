locals {
  min_node = 5
  max_node = 9
}
resource "random_string" "suffix" {
  length = 6
  upper = false
  special = false
}
locals {
  environment_prefix = "${var.environment_name}-${random_string.suffix.result}"
}

# using count and list - count uses list data strucutre to iterate
resource "random_string" "list" {
  count = length(var.regions)
  length = 6
  upper = false
  special = false
}

# using map and foreach - foreach is used in map data structure to iterate
resource "random_string" "map" {
  for_each = var.regions_instance_count
  length = 6
  upper = false
  special = false
  
}

# using conditionals
resource "random_string" "if_check" {
  count = var.enabled ? 1 : 0 # basically if value for 'Enabled' variable is true then count will be 1 otherwise 0 (it is called ternery operator)
  length = 6
  upper = false
  special = false
}

# Declaring a module
module "my_random_module" {
  source = "hashicorp/module/random"
  version = "1.0.0"
}

# referncing the custom module and that's a local module and tf knows it that's why no version declaration is needed
module "charlie"{
  source = "./modules/rando"
  length = 5
}