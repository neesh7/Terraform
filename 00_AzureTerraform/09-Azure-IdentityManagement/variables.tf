# In this file we declare our input variables
variable "application_name" {
  type = string
}
variable "environment_name" {
  type = string
}
variable "primary_location" {
  type = string
}
# Object ID of the Entra security group (or user) allowed to sign in to the VM with Entra ID.
# Leave null to skip the role assignment.
variable "vm_login_principal_object_id" {
  type    = string
  default = null
}