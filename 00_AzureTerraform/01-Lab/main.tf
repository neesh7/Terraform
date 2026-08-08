# HCL Syntax -  block paramete {args}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}


# Declaring local vairable
locals {
  # environment_prefix = "tip"
  # String interpolation - basically inserting dynamic vaues inside a string text
  environment_prefix = "${var.application_name}-${var.environment_name}-${random_string.suffix.result}"
}
