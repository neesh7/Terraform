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
  
  # # Regional stamps as a list
  # regional_stamps = [
  #   {
  #         region = "eastus"
  #         name = "foo"
  #         min_node = 4
  #         max_node = 8
  #   },
  #   {
  #         region = "westtus"
  #         name = "bar"
  #         min_node = 5
  #         max_node = 7
  #   }
  # ]

  # Regional Stamp as a map
  regional_stamps = {
    
      "foo" = {
          region = "eastus"
          min_node = 4
          max_node = 8},
      
      "bar" = {
          region = "westus"
          name = "bar"
          min_node = 5
          max_node = 7
            }
  }
}

# using custom modules again and again is bit clumsy a better appraoch is to iterate over them.
# module "regionA" {
#   source = "./modules/regional_stamp"
#   region = "westus"
#   name = "foo"
#   min_node = 4
#   max_node = 8
# }
# module "regionB" {
#   source = "./modules/regional_stamp"
#   region = "eastus"
#   name = "foo-2"
#   min_node = 5
#   max_node = 7
# }

##### Note on a list we can use count 
# module "regional_stamp" {

#   source = "./modules/regional_stamp"
#   count = length(local.regional_stamps)

#   region = local.regional_stamps[count.index].region
#   name = local.regional_stamps[count.index].name
#   min_node = local.regional_stamps[count.index].min_node
#   max_node = local.regional_stamps[count.index].max_node
# }


#### For a map we have to use For each
module "regional_stamp" {

  source = "./modules/regional_stamp"
  for_each = local.regional_stamps

  region = each.value.region
  name = each.key
  min_node = each.value.min_node
  max_node = each.value.max_node
}