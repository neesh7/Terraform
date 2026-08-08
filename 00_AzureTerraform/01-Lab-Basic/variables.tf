variable "application_name" {
  type = string
  description = "webapp"
  sensitive = false
  default = "webapp"
}
variable "environment_name" {
  type = string
  description = "tip"
  sensitive = false
  default = "tip"
}
#Terraform plan will interactively ask you to define the value before running apply or you can declare it too
# terraform plan -var "application_name=webapp" -var "environment_name=tip"