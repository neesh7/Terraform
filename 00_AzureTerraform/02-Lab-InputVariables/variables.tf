variable "foo" {
  type = string

  validation {
    condition = length(var.foo) <= 12
    # condition = true
     error_message = "foo must be less than or equal to 12 Characters"
  }
}
variable "environment_name" {
  type = string
}
variable "instance_count" {
  type = number
  validation {
    condition = var.instance_count >= local.min_node && var.instance_count < local.max_node && var.instance_count % 2 != 0
    error_message = "Must be between 5 and 10"
  }
}
variable "enabled" {
  type = bool
}
variable "regions" {
  type = list(string)
}
variable "regions_instance_count" {
  type = map(string)
}
variable "region_set" {
  type = set(string)
}
# Complex Data structure
variable "sku_settings" {
    type = object({
      kind = string
      tier = string
    })
}