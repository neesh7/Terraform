output "foo" {
  value = var.foo
}
# we can comment like this
// we can comment like this 
/* we can comment like this too */
output "count_instance" {
  value = var.instance_count
}
# Accessing list elements
output "primary_region" {
  value = var.regions[0]
}

# Accessing map elements
output "primary_region_instance" {
#   value = var.regions_instance_count["westus"]
    value = var.regions_instance_count[var.regions[0]]
}

output "kind" {
  value = var.sku_settings.kind
}