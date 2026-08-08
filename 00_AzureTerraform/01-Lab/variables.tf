variable "application_name" {
  type        = string
  description = "It contains the App name"
  sensitive   = false
  # default = "webapp" Only define default value when a fallback is needed
}
variable "environment_name" {
  type        = string
  description = "It contains the environment name"
  sensitive   = false
  # default = "testinprogress"
}
variable "api_key" {
  type = string
  description = "It is an API KEY"
  sensitive = true
}
# Terraform plan will interactively ask you to define the value before running apply or you can declare it too
# terraform plan -var "application_name=webapp" -var "environment_name=tip"