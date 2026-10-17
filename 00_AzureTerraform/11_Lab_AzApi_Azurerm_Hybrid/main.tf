# Step 1: Caller's identity - used for Key Vault access
data "azurerm_client_config" "current" {}

# Step 2: Look up the network from lab 07 (subnet for the VM, and the VNet for context)
# Nothing here is created by this lab, so these are read-only lookups
data "azurerm_subnet" "snet2" {
  name                 = "snet-2"
  virtual_network_name = "vnet-network-dev"
  resource_group_name  = "rg-network-dev"
}

# Step 3: Resource group for this lab's resources
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.primary_location
}

# Step 4: Static public IP for the VM
resource "azurerm_public_ip" "vm1" {
  name                = "pip-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Step 5: Network interface for the VM - sits in snet-2 and carries the public IP
resource "azurerm_network_interface" "vm1" {
  name                = "nic-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "public"
    subnet_id                     = data.azurerm_subnet.snet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1.id
  }
}

# Step 6: SSH key pair for the VM - the private key goes into Key Vault, never onto local disk
resource "tls_private_key" "vm1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Step 7: Key Vault to hold the SSH keys, with RBAC authorization like lab 09
resource "random_string" "keyvault_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.application_name}-${var.environment_name}-${random_string.keyvault_suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  rbac_authorization_enabled = true
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name                   = "standard"
}

# Step 8: Give the identity running Terraform permission to write secrets
resource "azurerm_role_assignment" "terraform_user_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Step 9: Store both halves of the SSH key pair as Key Vault secrets
# depends_on makes sure the role is in place before the secrets are written
resource "azurerm_key_vault_secret" "vm1_private_key" {
  name         = "vm1-private-key"
  value        = tls_private_key.vm1.private_key_pem
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.terraform_user_kv]
}

resource "azurerm_key_vault_secret" "vm1_public_key" {
  name         = "vm1-public-key"
  value        = tls_private_key.vm1.public_key_openssh
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.terraform_user_kv]
}

# Step 10: Linux VM - uses the NIC from step 5 and the SSH key from step 6
resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "vm1${var.application_name}${var.environment_name}"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = "Standard_D4_v2_Promo"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.vm1.id]

  # System-assigned managed identity for the VM itself
  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.vm1.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Step 11: azapi - the one property azurerm doesn't expose
# azurerm_linux_virtual_machine has no vCPU settings, so we patch the VM's
# hardwareProfile.vmSizeProperties through the ARM REST API (API version 2024-07-01).
# azapi_update_resource sends a PATCH, so it only touches the properties listed here
# and leaves everything azurerm manages (size, image, NIC, identity) alone.
resource "azapi_update_resource" "vm1_vcpu_per_core" {
  type        = "Microsoft.Compute/virtualMachines@2024-07-01"
  resource_id = azurerm_linux_virtual_machine.vm1.id

  body = {
    properties = {
      hardwareProfile = {
        vmSizeProperties = {
          # 1 = one vCPU per physical core (hyperthreading off). Default is usually 2.
          # Only some VM sizes accept this; if apply fails with an invalid-size error, set it to 2 or remove this block.
          vCPUsPerCore = 1
        }
      }
    }
  }
}
