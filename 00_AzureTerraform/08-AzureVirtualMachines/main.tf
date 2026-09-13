# Cerating resource group
resource "azurerm_resource_group" "main" {
  name = "rg-${var.application_name}-${var.environment_name}" # environment name will flow here from env/dev.tfvars or env/prod.tfvars
  location = var.primary_location
}


# Step:1 Create a Public IP Address so we can access our vm through internet
# In previous lab we already allowed our home network to access the vm by setting of source address prefix in NSG settings
# Now we need to create a public ip so our vm can be accessed through internet
resource "azurerm_public_ip" "vm1" {
  name                = "pip-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
}
# Getting the subnet info from older lab
data "azurerm_subnet" "snet2" {
  # name                 = "snet-1"
  name                 = "snet-2"
  virtual_network_name = "vnet-network-dev"
  resource_group_name  = "rg-network-dev"
}


# Step 2: Setting up NIC - Public ip is attached with the NIC so we can rdp or ssh into the vm using internet
resource "azurerm_network_interface" "vm1" {
  name                = "vm1-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "public"
    # subnet_id                     = data.azurerm_subnet.snet1.id
    subnet_id                     = data.azurerm_subnet.snet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1.id
  }
}
# SSH Key - to login into the vm
resource "tls_private_key" "vm1" {
  algorithm = "RSA"
  rsa_bits = 4096
}
# tls_private_key.vm1
# tls_private_key.vm1.public_key_openssh
# Now in able to login locally into this vm that is ssh we need to save the public and private keys into local files on our system
# Moved to Azure Key Vault instead of storing keys on local disk - see below
/*
resource "local_file" "private_key" {
  content = tls_private_key.vm1.private_key_pem
  filename = pathexpand("~/.ssh/vm1")
  file_permission = "0600"
}
resource "local_file" "public_key" {
  content = tls_private_key.vm1.public_key_openssh
  filename = pathexpand("~/.ssh/vm1.pub")
}
*/
# Data source to get current caller's identity so we can grant it access to the key vault
data "azurerm_client_config" "current" {}

resource "random_string" "keyvault_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_key_vault" "main" {
  name                        = "kv-${var.application_name}-${var.environment_name}-${random_string.keyvault_suffix.result}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  rbac_authorization_enabled  = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
}

# Grant the current caller permission to write/read secrets before we try to create any
resource "azurerm_role_assignment" "terraform_user_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

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

# Step 4: Virtual machine

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "vm1${var.application_name}${var.environment_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D4_v2_Promo"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.vm1.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    # public_key = file("~/.ssh/id_rsa.pub")
    public_key = tls_private_key.vm1.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical" # Ubuntu Linux image
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Step 5 : Login into vm using ssh
# ssh -i ~/.ssh/vm1 adminuser@<public-ip>
# ssh -i ~/.ssh/vm1 adminuser@4.227.105.29
# ssh -i C:\Users\Avaneesh\.ssh\vm1 adminuser@<public-ip>

# Step 6: Spinning up a Bastion Resource

# Getting the subnet info from older lab
data "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # exact name Azure requires for the Bastion subnet
  virtual_network_name = "vnet-network-dev"
  resource_group_name  = "rg-network-dev"
}


resource "azurerm_public_ip" "bastion" {
  name                = "${var.application_name}-${var.environment_name}-bastion"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "AzBastion"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = data.azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}