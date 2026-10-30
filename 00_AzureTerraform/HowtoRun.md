# How to run the labs

## Prerequisites

- Azure CLI signed in (`az login`) to the subscription you're using
- Set your subscription before running any script:
  ```bash
  export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
  ```
  The `.debug-dev.sh` scripts use this value if it's set. Otherwise they fall back to a placeholder.
- Run the scripts from inside the lab folder: `./.debug-dev.sh plan|apply|destroy`

## Order

| Step | Lab | Creates | Depends on |
|---|---|---|---|
| 1 | `04-AzTerraform-configuring-backend` | remote state storage | nothing |
| 2 | `07-AzureVirtualNetworks` | VNet, subnets, NSG | step 1 |
| 3 | one of the VM labs (below) | VM and related resources | step 2 |

Do not run `08` and `09` together. Both create a VM and a Bastion with overlapping names.

### Step 1: Backend (lab 04)

1. Apply the backend with its local state:
   ```bash
   terraform apply -var-file=env/dev.tfvars
   ```
2. Note the storage account name from the output (`backend_storage_account_name`).
3. Put that name in `backend.tf` and `BACKEND_STORAGE_ACCOUNT` in `.debug-dev.sh` for every lab that uses the backend (`05`, `06`, `07`, `08`, `09`, `10`, `11`). The names must match, or `init` fails.

### Step 2: Network (lab 07)

```bash
cd 07-AzureVirtualNetworks
./.debug-dev.sh plan
./.debug-dev.sh apply
```

Lab 07 owns `rg-network-dev`, `vnet-network-dev` and the subnets. Other labs read these by name, so keep the names unchanged.

### Step 3: Pick one VM lab

| Lab | What it builds | Notes |
|---|---|---|
| `09-Azure-IdentityManagement` | VM, Bastion, Key Vault, Entra group and login role | Full setup with Entra login. Uses `azurerm`. |
| `10_AzApi-Provider-Labs` | VM, NIC, public IP, Key Vault and secrets | `azapi` throughout. See the notes in its `ModuleNotes.md` before destroying. |
| `11_Lab_AzApi_Azurerm_Hybrid` | Same VM stack in `azurerm`, plus one `azapi` update for vCPU settings | Hybrid example. |
| `08-AzureVirtualMachines` | VM and Bastion | Older version. Don't run it alongside `09`. |

Each lab has its own state key, so you can run more than one lab, but the names will collide if you use the same `application_name`. Change `application_name` in `terraform.tfvars` and `.debug-dev.sh` if you want two labs side by side.

## Destroying

- Destroy in reverse order: VM labs first, then `07`, then `04`.
- **Lab 10:** the Key Vault secrets can't be deleted through ARM. Delete them with `az keyvault secret delete` and `terraform state rm`, then run `destroy`.
- Key Vault has soft delete (7 days). Purge it with `az keyvault purge` if you need the name back sooner.

## Troubleshooting

- **`Backend initialization required`**: the storage account name in `backend.tf` doesn't match the one in the script, or the account was deleted. Check `az storage account show`.
- **`Subnet ... was not found`**: lab 07 hasn't been applied, or it was deleted. Apply step 2 again.
- **`Error acquiring the state lock`**: a previous run stopped while holding the lock. Run `terraform force-unlock <LOCK_ID>`.
- **Plan asks for a variable**: `terraform.tfvars` or the `TF_VAR_*` exports are missing `application_name`, `environment_name` or `primary_location`.
