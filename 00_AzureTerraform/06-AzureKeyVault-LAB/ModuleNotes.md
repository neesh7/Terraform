# Azure Key Vault Lab

## Error: `VaultAlreadyExists` (409 Conflict)

```
Error: creating Key Vault ... VaultAlreadyExists: The vault name 'kv-devops-dev'
is already in use.
```

**Root cause:** Key Vault names are globally unique across all of Azure, and Azure
soft-deletes vaults by default (`soft_delete_retention_days`). Destroying a vault via
`terraform destroy` (or a failed/retried apply) doesn't remove it — it goes into a
recoverable, soft-deleted state for the retention period and **still reserves the name
globally**. A later `apply` using the same hardcoded name collides with it.

### Fix options

1. **Purge the old soft-deleted vault** (if you don't need to recover it):
   ```
   az keyvault purge --name kv-devops-dev --location <region>
   ```
2. **Recover it** instead of recreating (if you need the original contents back):
   ```
   az keyvault recover --name kv-devops-dev
   terraform import azurerm_key_vault.main <vault_id>
   ```
3. **Make the name unique** so repeated destroy/apply cycles in a lab don't collide —
   use the `random_string.keyvault_suffix` resource already declared in `main.tf`
   (currently commented out of the `name` argument):
   ```hcl
   name = "kv-${var.application_name}-${var.environment_name}-${random_string.keyvault_suffix.result}"
   ```

## Key Vault naming rules

- 3–24 characters, alphanumeric and hyphens only, must start with a letter.
- Globally unique across all of Azure (like storage accounts).

## Recommended naming convention

```
kv-<app>-<env>-<unique-suffix>
```
e.g. `kv-devops-dev-x7k2p9`

For this lab (frequent `apply`/`destroy` cycles), the random suffix avoids the
soft-delete name collision above. For real/prod environments, teams more often keep
predictable names (no random suffix) and instead rely on purge protection + an
explicit purge step in CI teardown so names can be safely reused.

## Other Azure resources with the same "globally unique name + soft-delete" trap

Key Vault isn't the only resource that can hit `AlreadyExists` after a destroy. Same
failure pattern applies to:

| Resource | Globally unique? | Soft-delete? | Notes |
|---|---|---|---|
| **Key Vault** | Yes | Yes (default on) | This lab |
| **Storage Account** | Yes | No soft-delete on the account itself | Just globally unique — clash if reused too soon, but no purge step needed |
| **App Configuration** (`azurerm_app_configuration`) | Yes | Yes (soft-delete default on) | `az appconfig purge` |
| **Cognitive Services / Azure OpenAI** (`azurerm_cognitive_account`) | Yes | Yes (soft-delete default on) | `az cognitiveservices account purge` |
| **API Management** (`azurerm_api_management`) | Yes (default `.azure-api.net` domain) | Yes (soft-delete for some SKUs) | `az apim` recovery/purge |
| **Recovery Services Vault** | No (unique per resource group) | No traditional soft-delete (backup items within it do) | Different mechanism |
| **Container Registry** (`.azurecr.io`) | Yes | No | Naming collision only, no purge needed |

Same fix pattern as Key Vault: add a `random_string` suffix to the name for lab/dev
churn, or run the matching `az <service> purge` command after a destroy before reusing
the name.

## `purge_soft_delete_on_destroy` provider setting

Added to `provider "azurerm" { features { key_vault { ... } } }` in `versions.tf`:

```hcl
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}
```

Makes `terraform destroy` actually purge the vault instead of just soft-deleting it,
so the next `apply` with the same vault name won't hit `VaultAlreadyExists` — a
provider-level fix for the same problem described above, useful for a lab with
frequent destroy/apply cycles.

## Access Policy vs RBAC authorization

Key Vault supports two permission models, controlled by `rbac_authorization_enabled`.

**Access Policy (legacy, default — `rbac_authorization_enabled = false`)** —
permissions live on the vault itself as a list of `(identity, [permissions])` entries
via `azurerm_key_vault_access_policy` resources.

**RBAC (`rbac_authorization_enabled = true`)** — permissions are managed the same way
as every other Azure resource: `azurerm_role_assignment` against built-in roles
(`Key Vault Secrets User`, `Key Vault Administrator`, `Key Vault Reader`, etc.), scoped
to the vault or even down to a single secret/key/cert.

**Why RBAC is preferred:**
1. One consistent permission model shared with every other Azure resource, instead of
   a Key-Vault-only mechanism.
2. Finer-grained scoping — down to a single secret/key/cert, not just the whole vault.
3. Centralized, auditable via Azure AD access reviews / PIM / `az role assignment list`
   — access policies don't integrate with any of that.
4. No 1024-entry limit (access policies cap out there).
5. Supports newer authorization features (deny assignments, ABAC conditions).
6. Microsoft's own recommended model going forward.

**Practical implication:** with `rbac_authorization_enabled = false` (current state),
access is granted via `azurerm_key_vault_access_policy`. Flipping to `true` means
access is granted via `azurerm_role_assignment` blocks instead — this is the step
below.

## Lab steps

1. Creating azure key vault
2. connecting data sources
3. Adding role assignments
4. enabling rbac
5. setting up diagnosting
6. always use azure portal json view to debug it right