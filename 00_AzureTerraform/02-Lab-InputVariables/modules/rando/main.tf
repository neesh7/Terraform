resource "random_string" "rando" {
  length = var.length
  upper = false
  special = false
}