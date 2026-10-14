# output "vm1_public_key" {
#   value = tls_private_key.vm1.public_key_openssh
# }

# output "vm1_private_key" {
#   value     = tls_private_key.vm1.private_key_pem
#   sensitive = true
# }
# terraform output -raw vm1_private_key
output "public_ip_address" {
    value = azurerm_public_ip.vm1.ip_address
}