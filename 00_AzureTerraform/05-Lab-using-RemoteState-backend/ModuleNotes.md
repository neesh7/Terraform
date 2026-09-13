# Remote State Backend (azurerm)

## Prerequisite: backend infra must exist BEFORE `terraform init`

Terraform does not create its own backend. The RG + storage account + blob container
must already exist. Only the state blob (`key`) is created by Terraform on first init.

Run `../04-AzTerraform` first (it has NO backend block, so it uses local state) to provision:

| Resource | Name pattern |
|---|---|
| `azurerm_resource_group.main`       | `rg-<application_name>-<environment_name>` |
| `azurerm_storage_account.main`      | `st<random_string>` (globally unique, lowercase, <=24 chars) |
| `azurerm_storage_container.tfstate` | `tfstate` |

```
az login                                  # or set ARM_* env vars for a service principal
export ARM_SUBSCRIPTION_ID="<sub-id>"     # az account show --query id -o tsv
cd ../04-AzTerraform
terraform init
terraform apply -var-file ./env/dev.tfvars
```

Read the values back from state instead of the Azure portal:

```
terraform output backend_resource_group_name
terraform output backend_storage_account_name
terraform output backend_container_name
# or from another dir: terraform -chdir=../04-AzTerraform output -raw backend_storage_account_name
```

Note: `azurerm_storage_blob.tfstatefile` in `04/main.tf` is redundant — the backend
manages the state blob itself via `key`.

## subscription_id

Not set in `.tf` on purpose. azurerm 5.x auto-picks the Azure CLI's active subscription (`az login`); industry standard is to inject `ARM_SUBSCRIPTION_ID` per-environment (OIDC in CI), never a hardcoded GUID in committed code.

## What `key` signifies

`key` is the blob name of this config's state file inside `container_name`, i.e.
`<storage account>/<container>/<key>`. It's just an identifier you pick — not a
variable or secret. It must be unique per config sharing the container (same `key`
= two configs clobbering each other's state); slashes are only a pseudo-folder in
the portal. It's the remote equivalent of the local `terraform.tfstate` path.

## Wire up this lab

The `backend` block cannot use variables, locals, `data` sources, or remote-state
outputs — every value must be a literal. Two options:

### Option A — hardcode in `versions.tf`
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-..."          # from 04 output
    storage_account_name = "st<random>"      # from 04 output
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
```

### Option B — partial config (keeps generated values out of the file)
`versions.tf` keeps only static values:
```hcl
terraform {
  backend "azurerm" {
    key = "dev.terraform.tfstate"
  }
}
```
Supply the rest at init:
```
RG=$(terraform -chdir=../04-AzTerraform output -raw backend_resource_group_name)
SA=$(terraform -chdir=../04-AzTerraform output -raw backend_storage_account_name)
CN=$(terraform -chdir=../04-AzTerraform output -raw backend_container_name)
terraform init \
  -backend-config="resource_group_name=$RG" \
  -backend-config="storage_account_name=$SA" \
  -backend-config="container_name=$CN"
# or put those key=value lines in backend.hcl and: terraform init -backend-config=backend.hcl
```

## init behavior

- First `init` with a backend block on a config that already has local state prompts:
  *"Do you want to copy existing state to the new backend?"* — yes to migrate.
- Changed backend values later: `terraform init -reconfigure` (ignore old state) or
  `-migrate-state` (move it).
- The azurerm backend locks state via a blob lease automatically — no extra config,
  unlike local state which has no locking.

## Why bootstrap can't self-host the backend

You cannot put the `azurerm` backend block inside `04-AzTerraform` — `init` would need the
storage account before Terraform has created it. Bootstrap stays on local state; only
downstream configs (like this lab) point at the remote backend.


# how to use shell or local runners to run our terrraform script ?
