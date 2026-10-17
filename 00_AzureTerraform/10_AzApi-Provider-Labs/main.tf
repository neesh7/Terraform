# Step 1: Caller's subscription and identity - azapi resources need an explicit parent scope
data "azapi_client_config" "current" {}

# Step 2: Look up the network from lab 07 (resource group -> VNet -> subnet)
# Nothing here is created by this lab, so these are read-only lookups
data "azapi_resource" "network_rg" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = "rg-network-dev"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
}

# Subnets are children of a VNet, so the VNet has to be looked up first
data "azapi_resource" "network_vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-network-dev"
  parent_id = data.azapi_resource.network_rg.id
}

# The VM's NIC attaches to this subnet
data "azapi_resource" "snet-2" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "snet-2"
  parent_id = data.azapi_resource.network_vnet.id

  response_export_values = ["properties.addressPrefix"]
}

# Step 3: Resource group for this lab's resources
# type = <ARM resource type>@<api-version>, reference: https://learn.microsoft.com/en-us/azure/templates/
resource "azapi_resource" "rg" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = "rg-${var.application_name}-${var.environment_name}"
  location  = var.primary_location
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  body      = {}
}

# Step 4: Static public IP for the VM, created inside this lab's resource group
resource "azapi_resource" "vm_pip" {
  type      = "Microsoft.Network/publicIPAddresses@2024-05-01"
  name      = "pip-${var.application_name}-${var.environment_name}"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id
  body = {
    sku = {
      name = "Standard"
    }
    properties = {
      publicIPAllocationMethod = "Static"
    }
  }
}

# Step 5: Network interface for the VM - sits in snet-2 and carries the public IP
resource "azapi_resource" "vm_nic" {
  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "nic-${var.application_name}-${var.environment_name}"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id
  body = {
    properties = {
      ipConfigurations = [
        {
          name = "public"
          properties = {
            privateIPAllocationMethod = "Dynamic"
            subnet = {
              id = data.azapi_resource.snet-2.id
            }
            publicIPAddress = {
              id = azapi_resource.vm_pip.id
            }
          }
        }
      ]
    }
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

resource "azapi_resource" "keyvault" {
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  name      = "kv-${var.application_name}-${var.environment_name}-${random_string.keyvault_suffix.result}"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id
  body = {
    properties = {
      tenantId                  = data.azapi_client_config.current.tenant_id
      sku                       = { family = "A", name = "standard" }
      enableRbacAuthorization   = true
      softDeleteRetentionInDays = 7
    }
  }
}

# Step 8: Give the identity running Terraform permission to write secrets
# Role assignment names must be GUIDs, so generate one that stays stable across plans
resource "random_uuid" "kv_admin_assignment" {}

resource "azapi_resource" "kv_admin_assignment" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.kv_admin_assignment.result
  parent_id = azapi_resource.keyvault.id
  body = {
    properties = {
      # 00482a5a-887f-4fb3-b363-3b7fe8e74483 = Key Vault Administrator
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483"
      principalId      = data.azapi_client_config.current.object_id
    }
  }
}

# Step 9: Store both halves of the SSH key pair as Key Vault secrets
# depends_on makes sure the role is in place before the secrets are written
resource "azapi_resource" "vm1_private_key" {
  type      = "Microsoft.KeyVault/vaults/secrets@2023-07-01"
  name      = "vm1-private-key"
  parent_id = azapi_resource.keyvault.id
  body = {
    properties = {
      value = tls_private_key.vm1.private_key_pem
    }
  }
  depends_on = [azapi_resource.kv_admin_assignment]

  # ARM returns location (read-only, the vault's location) for secrets, which would
  # otherwise show as a change and force a replace. Azure can't delete secrets via ARM.
  schema_validation_enabled = false

  lifecycle {
    ignore_changes = [location]
  }
}

resource "azapi_resource" "vm1_public_key" {
  type      = "Microsoft.KeyVault/vaults/secrets@2023-07-01"
  name      = "vm1-public-key"
  parent_id = azapi_resource.keyvault.id
  body = {
    properties = {
      value = tls_private_key.vm1.public_key_openssh
    }
  }
  depends_on = [azapi_resource.kv_admin_assignment]

  # Same as the private key secret: ignore the read-only location returned by ARM
  schema_validation_enabled = false

  lifecycle {
    ignore_changes = [location]
  }
}

# Step 10: Linux VM - uses the NIC from step 5 and the SSH key from step 6
# Same image and login settings as lab 09, with a system-assigned identity
resource "azapi_resource" "vm1" {
  type      = "Microsoft.Compute/virtualMachines@2024-07-01"
  name      = "vm1${var.application_name}${var.environment_name}"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      hardwareProfile = {
        vmSize = "Standard_D4_v2_Promo"
      }
      osProfile = {
        computerName  = "vm1${var.application_name}${var.environment_name}"
        adminUsername = "adminuser"
        linuxConfiguration = {
          disablePasswordAuthentication = true
          ssh = {
            publicKeys = [
              {
                path    = "/home/adminuser/.ssh/authorized_keys"
                keyData = tls_private_key.vm1.public_key_openssh
              }
            ]
          }
        }
      }
      storageProfile = {
        imageReference = {
          publisher = "Canonical"
          offer     = "0001-com-ubuntu-server-jammy"
          sku       = "22_04-lts"
          version   = "latest"
        }
        osDisk = {
          createOption = "FromImage"
          caching      = "ReadWrite"
          managedDisk = {
            storageAccountType = "Standard_LRS"
          }
        }
      }
      networkProfile = {
        networkInterfaces = [
          {
            id = azapi_resource.vm_nic.id
            properties = {
              primary = true
            }
          }
        ]
      }
    }
  }
}
