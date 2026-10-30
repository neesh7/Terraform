Till now we have used 2 terraform providers
- azurerm
- azuread
but now we are going to explore another provider called 'azapi'.


Terraform Providers are independent pieces of software that extend the terraform core cli to allow us to talk different platform.

In Azurerm provider what's happening it is eseentially using azure sdk in golang sdk for azure

If any new feature released in azure then there is some custom coding involved in azurerm provider where author basically writes how to achieve that piece in terraform and this causes a delay and delay can be long or short.

AzureAPI provider on the other hand is maintained by microsoft itself so it have the day 0 support to any of this features.

How azure api provider work and different from azurerm provider ?

- Day 0 Support to any azure feature
- it Allows us to use the official schema of that azure resource, rather than a proprietary abstraction that is built in to terraform provider.
Resources

https://learn.microsoft.com/en-us/azure/templates/
https://registry.terraform.io/providers/Azure/azapi/latest

---

## What we implemented in this lab

Everything here is built with `azapi_resource`, which takes the ARM resource type and API version directly.

| Step | Resource | ARM type |
|---|---|---|
| 1 | caller identity | `data "azapi_client_config"` |
| 2 | network from lab 07 (read-only) | `resourceGroups`, `virtualNetworks`, `virtualNetworks/subnets` lookups |
| 3 | resource group | `Microsoft.Resources/resourceGroups@2024-03-01` |
| 4 | static public IP | `Microsoft.Network/publicIPAddresses@2024-05-01` |
| 5 | NIC in `snet-2` with the public IP | `Microsoft.Network/networkInterfaces@2024-05-01` |
| 6 | SSH key pair | `tls_private_key` (not azapi) |
| 7 | Key Vault with RBAC | `Microsoft.KeyVault/vaults@2023-07-01` |
| 8 | Key Vault Administrator for the caller | `Microsoft.Authorization/roleAssignments@2022-04-01` |
| 9 | private and public key as secrets | `Microsoft.KeyVault/vaults/secrets@2023-07-01` |
| 10 | Linux VM with system-assigned identity | `Microsoft.Compute/virtualMachines@2024-07-01` |

### How azapi resources differ from azurerm

- **The type carries the API version.** `Microsoft.Network/publicIPAddresses@2024-05-01` pins the schema, so you can see exactly which ARM contract you're writing against.
- **`parent_id` is the scope.** A resource group's parent is the subscription. Everything else's parent is its containing resource (for example, a subnet's parent is its VNet). Pass the ID, not the name.
- **`body` is the ARM payload.** It mirrors the REST API JSON, so the Azure template reference is the documentation.
- **`response_export_values` exports values** from the returned resource, such as `properties.addressPrefix` for a subnet.
- **Data lookups use the same shape.** `data "azapi_resource"` reads an existing resource by type, name and parent.

### Problems we hit (and what they taught us)

1. **Secrets can't be deleted through ARM.** `Microsoft.KeyVault/vaults/secrets` returns `405 DeleteNotSupported`. Any destroy, or any change that forces a replace, fails. Secrets are data-plane objects, so `azurerm_key_vault_secret` (which lab 09 uses) is the safer choice for them.
2. **`location` on secrets is read-only.** ARM returns the vault's location, so a config that doesn't set it sees a change and forces a replace. Setting it is rejected too. `lifecycle { ignore_changes = [location] }` stops the replace, and `schema_validation_enabled = false` stops the validator from rejecting the config. Both are workarounds, not fixes.
3. **Role assignment names must be GUIDs.** Use `random_uuid` so the name is stable across plans.
4. **The VM was created in ~56 seconds**, and the NIC and public IP had to exist first. Terraform ordered them correctly from the references.

### When to use azapi here

Most of this lab could use `azurerm`. Use azapi for the parts where you need the day-0 ARM schema or a version that `azurerm` doesn't expose. `11_Lab_AzApi_Azurerm_Hybrid` shows the hybrid approach: `azurerm` for most resources, and one `azapi_update_resource` for a property `azurerm` doesn't expose (`vmSizeProperties.vCPUsPerCore`).

### Before you destroy

- Destroy the secrets with `az keyvault secret delete` and `terraform state rm`, or the destroy fails on them.
- The private key lives in Terraform state in plain text, so the backend has to stay private.
- Changing `vCPUsPerCore` may restart the VM.