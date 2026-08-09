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