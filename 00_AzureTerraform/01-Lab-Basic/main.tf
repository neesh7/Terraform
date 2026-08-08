# block paramete {args}

resource random_string suffix {
    length = 6
    upper = false
    special = false
}


# Declaring local vairable
locals {
  environment_prefix = "tip"
}