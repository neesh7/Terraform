# Terraform State

State (`terraform.tfstate`) is a JSON file where Terraform maps **real-world resources ↔ resources in your config**. Without it, Terraform has no idea what it already created.

## Why State Exists
1. **Mapping** - links `azurerm_resource_group.rg` in code to the real resource ID in Azure
2. **Metadata** - tracks dependencies (needed to destroy in the right order even after a resource is removed from config)
3. **Performance** - caches attribute values so big infra doesn't need a full API refresh every time
4. **Syncing** - with a remote backend, the whole team works from the same state

> Terraform compares **Config (desired)** vs **State (last known)** vs **Real infra (refresh)** to build the plan.

## What's Inside the State File
```json
{
  "version": 4,                // state file format version
  "terraform_version": "1.9.0",
  "serial": 7,                 // increments on every state write
  "lineage": "a1b2c3...",      // unique ID set when the state is first created
  "outputs": { },
  "resources": [ ]             // every managed resource + data source with its attributes
}
```
- **serial + lineage** stop you from overwriting a newer state or pushing a state from a different project
- `terraform.tfstate.backup` = the previous version, written automatically by local state

## Important Points (Exam)
1. State is stored **in plain text**, so **secrets and sensitive values are visible** in it. `sensitive = true` only hides values in CLI output, **not in state** (how to protect it → [05 › sections 6-7](05-Terraform_Security.md))
2. **Never commit state to Git**. Add `*.tfstate`, `*.tfstate.*` and `.terraform/` to `.gitignore` (but **do** commit `.terraform.lock.hcl`)
3. **Never edit state by hand**. Use `terraform state` commands
4. The default backend is **local** (`terraform.tfstate` in the working directory)
5. **State locking** stops two people writing at once. It happens automatically on any command that writes state (plan, apply, destroy...)
6. Backend blocks take **literal values only**, and changing them needs `terraform init` again (rules → [01 › Terraform Settings Block](01-Terraform_Configurations.md))
7. Data sources are also stored in state

## Local vs Remote Backend
| | Local | Remote (azurerm / s3 / gcs / HCP Terraform) |
|---|---|---|
| Storage | Your disk (`terraform.tfstate` in the working directory) | Shared, centralized storage |
| Team collaboration | No, hard to share safely | Yes |
| Locking | Yes (on the local system) | Yes (if the backend supports it) |
| Encryption at rest | No | Usually yes |
| Access control | None | IAM / RBAC |
| Audit logging | None | Generally available |
| Versioning / recovery | `.backup` file only | Blob versioning / S3 versioning |
| Secrets on laptops | Yes (risky), and easy to commit to Git by accident | No |

### Azure Backend (azurerm)
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate001"
    container_name       = "tfstate"
    key                  = "prod/network.tfstate"   # blob name
    use_azuread_auth     = true                     # use Entra ID instead of the access key
    # use_oidc = true                               # CI/CD (GitHub Actions / Azure DevOps) with workload identity
    # use_msi  = true                               # managed identity (self-hosted agent / VM)
  }
}
```
- Locking = **Blob lease** (native, no extra setup)
- Turn on **blob versioning + soft delete** on the storage account so you can recover state
- Full hardening (CMK, RBAC, private endpoint, resource lock, hardened storage account code) → [05 › section 6](05-Terraform_Security.md)

### AWS Backend (s3)
```hcl
terraform {
  backend "s3" {
    bucket       = "my-tf-state"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true        # server-side encryption (AES-256)
    kms_key_id   = "<kms_id>"  # optional: encrypt with your own KMS key
    use_lockfile = true        # native S3 locking (TF 1.10+). Older setups used dynamodb_table
  }
}
```
> **Note:** DynamoDB-based state locking (`dynamodb_table`) is **deprecated** since TF 1.11 and will be removed in a future release. Use `use_lockfile = true` (S3 native locking) instead.

### Partial Backend Configuration
Keep environment-specific or secret values out of code and pass them at init time:
```bash
terraform init -backend-config="key=dev.tfstate"
terraform init -backend-config=backend-dev.hcl
```

## State Commands
| Command | What it does |
|---|---|
| `terraform state list` | List all resources in state |
| `terraform state show <addr>` | Show the attributes of one resource |
| `terraform state mv <src> <dst>` | Rename / move a resource address (no destroy/recreate) |
| `terraform state rm <addr>` | Stop managing a resource (**the real resource is NOT deleted**) |
| `terraform state pull` | Print the remote state to stdout |
| `terraform state push <file>` | Overwrite the remote state (dangerous; `-force` skips the lineage/serial checks) |
| `terraform state replace-provider <old> <new>` | Change the provider source in state |
| `terraform show` | Human-readable view of the state (or of a saved plan) |
| `terraform output` | Read outputs from state |
| `terraform force-unlock <LOCK_ID>` | Release a stuck lock |
| `terraform init -migrate-state` / `-reconfigure` | Move state to a new backend / re-init without moving it (see **Migrating State** below) |
| `terraform import <addr> <id>` | Bring an existing resource into state (old CLI way) |
| `terraform apply -refresh-only` | Update state to match real infra, with no infra changes (replaces `terraform refresh`) |
| `terraform apply -replace=<addr>` | Force recreate one resource (replaces `terraform taint`) |
| `terraform plan -refresh=false` | Skip the refresh and plan only from state (faster, less safe) |
| `terraform apply -lock=false` | Turn off locking (avoid this) |
| `terraform apply -lock-timeout=60s` | Wait for the lock instead of failing straight away |

```bash
# Common examples
terraform state list
terraform state show azurerm_resource_group.rg
terraform state mv azurerm_storage_account.old azurerm_storage_account.new
terraform state mv 'azurerm_subnet.sub[0]' 'azurerm_subnet.sub["web"]'   # count -> for_each
terraform state mv azurerm_vnet.vnet module.network.azurerm_vnet.vnet      # move into a module
terraform state rm azurerm_key_vault.kv
terraform state pull > backup.tfstate
```

## Config-Driven Blocks (the modern way, reviewed in plan)
These go in code instead of running CLI commands, so they're reviewable in PRs and show up in `plan`.

> **Modern recommendation:** HashiCorp now recommends **config-driven blocks over the imperative CLI commands**. Blocks go through the normal `plan` → `apply` workflow, so they're previewed, version-controlled, work in CI/CD and HCP Terraform without anyone running state commands by hand, and apply to every workspace/env consistently. Keep the CLI commands for one-off fixes.

| Old CLI command | Modern block | Version |
|---|---|---|
| `terraform import` | `import {}` | 1.5+ |
| `terraform state mv` | `moved {}` | 1.1+ |
| `terraform state rm` | `removed {}` | 1.7+ |
| `terraform taint` | `apply -replace=<addr>` (flag, not a block) | 0.15.2+ |

Syntax, rules, import workflows and refactoring scenarios for all three blocks → [03 › sections 5-6](03-Making-Code-Reusable.md).

## Remote State Data Source
Read the **outputs** of another configuration's state (e.g. the app stack reads the network stack's subnet ID):
```hcl
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate001"
    container_name       = "tfstate"
    key                  = "prod/network.tfstate"
  }
}

subnet_id = data.terraform_remote_state.network.outputs.subnet_id
```
- Only **root module outputs** can be read
- The reader needs read access to the **whole** state file (a security concern). Alternatives: `tfe_outputs`, or data sources that look up the resource directly

## Workspaces (CLI)
A workspace = a **separate state file for the same config + same backend**. One codebase, many independent copies of the infra.

> ⚠️ **CLI workspaces ≠ HCP Terraform workspaces.** A CLI workspace is **just another state file**. An HCP Terraform workspace is a full working unit (config + state + variables + credentials + permissions + run history). Same name, different concept (details below).

### Commands
```bash
terraform workspace list            # * marks the current one
terraform workspace show            # current workspace
terraform workspace new dev         # create + switch
terraform workspace select prod     # switch
terraform workspace select -or-create test   # TF 1.4+
terraform workspace delete dev      # must not be current; state must be empty (or -force)
```
Or set `TF_WORKSPACE=dev` (an env var, handy in CI).

### Where the state is stored
| Backend | `default` workspace | Other workspaces |
|---|---|---|
| Local | `terraform.tfstate` | `terraform.tfstate.d/<ws>/terraform.tfstate` |
| azurerm | `<key>` | `<key>env:<ws>` (same container) |
| s3 | `<key>` | `env:/<ws>/<key>` (`workspace_key_prefix`) |

### Using it in code
```hcl
locals {
  env = terraform.workspace

  vm_size = {
    dev  = "Standard_B2s"
    prod = "Standard_D4s_v5"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-app-${local.env}"
  location = "eastus"
}

resource "azurerm_linux_virtual_machine" "vm" {
  size = lookup(local.vm_size, local.env, "Standard_B2s")
  # ...
}
```
Variable files per workspace: `terraform apply -var-file="${env}.tfvars"` (not automatic, you have to pass it).

### Use Cases ✅
1. **Short-lived / identical copies**: feature branches, PR preview envs, testing a change without touching the main state
2. **Same infra, different instances**: e.g. the same setup per region or per customer, where the config is identical and only names change
3. **Dev / test sandboxes** with small differences, handled through `terraform.workspace` lookups
4. **Learning / demos**: quickly spin up and destroy copies

### Limitations ❌
1. **Same backend = same credentials**. Whoever can access dev state can access prod state. **No security isolation**
2. **Same code for every env**. You can't easily run a newer module version in dev than in prod. Every env changes together
3. **Easy to apply in the wrong workspace**. The current workspace isn't shown in the prompt/plan output clearly → `terraform destroy` in prod by mistake
4. **Lots of conditionals**. Big env differences end up as `terraform.workspace == "prod" ? ... : ...` everywhere, which gets hard to read
5. **Not visible in code**. Looking at the repo, you can't tell which envs exist
6. **Same provider config / subscription** by default. Deploying each env to a different subscription or account needs extra logic
7. **The backend config itself can't change per workspace**, e.g. you can't put prod state in a separate, locked-down storage account

> **HashiCorp's own guidance:** CLI workspaces are **not a good fit** for separating environments that need strong isolation (separate credentials / access controls). Use separate directories / root modules with separate backends for that.

### Workspaces vs Directory-per-Environment
| | CLI Workspaces | Separate directories (`envs/dev`, `envs/prod`) |
|---|---|---|
| Code | One copy | Per env (calls shared modules) |
| State / backend | Same backend, different state | Separate backend per env |
| Access isolation | ❌ | ✅ (separate storage account / subscription / RBAC) |
| Different versions per env | ❌ | ✅ (pin a module version per env) |
| Wrong-env risk | High | Low (you `cd` into the env) |
| Best for | Temporary / identical copies | **Prod-level dev/stage/prod** ✅ |

### HCP Terraform Workspaces ≠ CLI Workspaces
- **HCP Terraform workspace** = config + state + variables + credentials + run history + permissions. It's more like a **separate directory/project**, with its own access control
- **CLI workspace** = just another state file in the same backend
- With the `cloud {}` block, `workspaces { tags = [...] }` maps several HCP workspaces, and `terraform workspace select` switches between them

### Exam Points
- `default` workspace always exists and **can't be deleted**
- `terraform.workspace` gives the current workspace name
- `workspace new` creates **and** switches to it
- Each workspace has its **own state**, and they share the same config and backend
- Not every backend supports multiple workspaces (most do: local, azurerm, s3, gcs, consul, kubernetes...)

## Migrating State
```bash
# Local -> remote: add the backend block, then
terraform init -migrate-state

# Changed backend config but DON'T want to copy the state
terraform init -reconfigure

# Remote -> local: remove the backend block, then
terraform init -migrate-state
```

## Drift Management
Drift = someone changed the infra outside Terraform (portal / CLI / script), so **real infra ≠ state ≠ code**.

### Step 1: Detect
```bash
terraform plan                 # refreshes and shows the changes needed to bring infra back to the code
terraform plan -refresh-only   # shows ONLY what changed outside Terraform (state vs real infra)
terraform plan -detailed-exitcode   # exit 0 = no changes, 1 = error, 2 = changes/drift (use in CI)
```
The plan output marks it as **"Objects have changed outside of Terraform"**.

### Step 2: Decide (revert or accept)
| Goal | What to do | What changes |
|---|---|---|
| **Revert the drift** (code is right) | `terraform plan` → `terraform apply` | **Real infra** goes back to match the code. State gets updated |
| **Accept the drift** (the manual change is right) | Update the **code** to match → `plan` shows no changes → `apply` | Code + state now match the infra |
| **Accept the drift into state only** | `terraform apply -refresh-only` | **Only state** is updated. Infra is untouched |
| **Ignore it permanently** | `lifecycle { ignore_changes = [tags] }` | Terraform stops tracking that attribute |

#### `plan -refresh-only` vs `apply -refresh-only`
| | `terraform plan -refresh-only` | `terraform apply -refresh-only` |
|---|---|---|
| What it does | **Previews** what changed outside Terraform | **Writes** those changes into state |
| Updates state? | ❌ No (read-only) | ✅ Yes (`serial` +1) |
| Changes infra? | ❌ No | ❌ No |
| Takes the state lock? | Yes, while it reads | Yes |
| Asks for approval? | No | Yes (`yes` prompt, unless `-auto-approve`) |
| Use it for | Checking drift safely / CI drift checks | Accepting drift into state / fixing stale outputs |

> Think of it as `plan` = **look**, `apply` = **commit**. Run `plan -refresh-only` first to review, then `apply -refresh-only` if you want to accept the changes. `terraform refresh` (deprecated) = `apply -refresh-only -auto-approve`, which is why it's risky: it writes without asking.

> `-refresh-only` on its own isn't a full fix. If the code still says something else, the next `plan` will try to revert it. Always update the code too.

### With a Remote Backend (azurerm / s3 / HCP Terraform)
The commands are the same. What's different:
1. **State lives remotely**, so `apply -refresh-only` writes the refreshed state **straight to the backend** (blob/S3), and everyone on the team sees the updated state
2. **Locking**: both `apply` and `apply -refresh-only` take the state lock (blob lease / S3 lockfile) during the run, so nobody else can write to state at the same time
3. **The state version changes**: `serial` goes up by one. With blob/S3 versioning on, you can roll back if a refresh-only apply recorded something wrong
4. **Back it up before you accept drift**: `terraform state pull > before-drift.tfstate`
5. **CI/CD**: run a scheduled `terraform plan -detailed-exitcode` (exit code 2 = drift) and alert or open a ticket
6. **HCP Terraform**: has built-in **drift detection (health assessments)** that runs refresh-only plans on a schedule and reports drift in the UI. Accepting it = start a **refresh-only run**

### Flow
```
Drift detected (plan / scheduled job)
   ├─ Manual change is WRONG  → terraform apply                    (infra fixed to match code)
   └─ Manual change is RIGHT  → update code → plan (no changes) → apply
                                 (or apply -refresh-only to sync state first, then update code)
```

**Prevention**: lock down portal write access (RBAC / Azure Policy / resource locks), make all changes through the pipeline, and run drift checks on a schedule.

---

## Scenarios (Interview / Real World)

**1. State file deleted / corrupted**
→ Restore from blob versioning / soft delete (Azure) or S3 versioning, or from `terraform.tfstate.backup`. If nothing is available: rewrite the code and `import` every resource again. *Lesson: always use a remote backend with versioning.*

**2. "Error acquiring the state lock"**
→ Check whether someone's apply/pipeline is really still running. If the lock is stale (crashed pipeline): `terraform force-unlock <LOCK_ID>`. On Azure you can also break the blob lease. Never use `-lock=false` as a fix.

**3. Renamed a resource in code, plan shows destroy + create**
→ Add a `moved` block (or `terraform state mv`). Plan should show "has moved", with no destroy.

**4. Converting `count` to `for_each`**
→ Index addresses `[0]` become key addresses `["web"]`. Use `moved` blocks / `state mv` for each instance, or everything gets recreated.

**5. Resource created manually in the portal, now needs Terraform**
→ `import` block + `terraform plan -generate-config-out=generated.tf`, clean up the code, and plan until there are no changes.

**6. Stop managing a resource without deleting it** (e.g. hand it to another team)
→ `removed` block with `destroy = false`, or `terraform state rm`.

**7. Splitting a big monolithic state into smaller ones** (network / app / data)
→ `state pull` for a backup → `terraform state mv -state-out=...` (local), or `removed` in the old config + `import` in the new one. Then link the stacks with `terraform_remote_state` / data sources.

**8. Secrets in state**
→ Lock down and encrypt the backend, fetch secrets at runtime, and use **ephemeral resources / write-only args** so they never reach state. Full answer → [05 › sections 5-7](05-Terraform_Security.md).

**9. Someone deleted a resource in the portal**
→ Next `plan` refreshes, sees it's gone, and plans to **create** it again. If it shouldn't come back, remove it from the code too.

**10. Two engineers apply at the same time**
→ The remote backend lock blocks the second one. Go further and run applies only through CI/CD (single writer).

**11. Moving from local state to Azure Storage**
→ Create the storage account (often with a separate bootstrap config), add the `backend "azurerm"` block, run `terraform init -migrate-state`, confirm with yes, then delete the local state file.

**12. State organisation strategy**
→ One state per **environment × component** (e.g. `prod/network.tfstate`). Smaller blast radius, faster plans, fewer people blocked by the lock. Use separate storage accounts / subscriptions for prod vs non-prod.

---

## Scenario Deep Dive: Lost Access to Remote State (Prod Approach)

**The risk:** if Terraform runs against an empty or new state, it thinks nothing exists and `plan` shows **every resource as `+ create`**. If you apply, you get duplicates, or failures on names that must be unique (azurerm usually errors with *"A resource with the ID ... already exists - to be managed via Terraform this resource needs to be imported into the State"*).

### Step 0: STOP
- **Freeze all pipelines** for that stack. Nobody runs `apply`.
- Never "just apply and see". An empty state + apply = duplicate infra, or partial failures that leave a mess.

### Step 1: Diagnose. Is it lost **access** or lost **state**?
Most of the time the state still exists and only the access is broken:
| Cause | Fix |
|---|---|
| RBAC removed / SPN or managed identity changed | Give back `Storage Blob Data Contributor` on the container |
| Storage access key rotated / SAS expired | Update the pipeline secret / switch to `use_azuread_auth` |
| Firewall / private endpoint blocking the runner | Allow the runner's IP / VNet |
| Wrong `key`, container or subscription in the backend config | Fix `-backend-config` and run `terraform init -reconfigure` |
| Storage account / blob deleted | Go to Step 2 |

> If it's just access → **fix the access, don't rebuild state**. Importing is the last resort.

### Step 2: Recover the state file (before you import anything)
In order of preference:
1. **Blob soft delete / versioning**: restore the previous version of the blob (Portal → container → blob → Versions)
2. **Storage account soft delete / resource lock**: recover the deleted storage account
3. **Backups**: a `state pull` copy, a pipeline artifact, or a backup copy in another storage account
4. Push the recovered file back:
   ```bash
   terraform init
   terraform state push recovered.tfstate    # checks lineage/serial; -force only if you're sure
   terraform plan                            # expect "No changes" or only small drift
   ```

### Step 3: Rebuild the state with `import` blocks (only if the state is gone for good)
1. **Set up a new, hardened backend** (versioning + soft delete + `CanNotDelete` lock), then `terraform init`
2. **List what exists**: `az resource list -g <rg>`, Azure Resource Graph, or tags like `managed-by = terraform`
3. **Write import blocks** (in a separate `imports.tf`). Use `for_each` for many resources (TF 1.7+):
   ```hcl
   locals {
     rgs = { app = "rg-app-prod", data = "rg-data-prod" }
   }

   import {
     for_each = local.rgs
     to       = azurerm_resource_group.this[each.key]
     id       = "/subscriptions/${var.subscription_id}/resourceGroups/${each.value}"
   }
   ```
4. **Code is missing?** Generate it, then clean it up (remove computed/default values, use variables):
   ```bash
   terraform plan -generate-config-out=generated.tf
   ```
5. **Plan until it's clean.** The goal is: `Plan: N to import, 0 to add, 0 to change, 0 to destroy`
   - Any `create` → that resource is still missing an import block
   - Any `update` / `replace` → the code doesn't match the real infra. **Fix the code, not the infra**
   - **Never apply while the plan shows `destroy` or `replace`**
6. **Apply one component at a time** (network → data → app), get a PR review, and apply through the pipeline
7. **Check**: `terraform state list` covers everything, and the next `terraform plan` = **No changes**
8. **Remove the import blocks** in a follow-up PR (once imported, they do nothing)

### Things to watch out for
- **Secrets / write-only values** (VM admin password, keys) can't be read back. Set them from Key Vault in code, or use `ignore_changes`
- **Some resources can't be imported** (e.g. `tls_private_key`, `null_resource`, `terraform_data`). These are Terraform-only resources, so let them be recreated on purpose (and check what depends on them)
- **Child resources** (role assignments, NSG rules, subnet associations) need their own import blocks, and they're easy to miss
- **Import IDs are case-sensitive** in azurerm (`resourceGroups` vs `resourcegroups`)
- Import blocks go through `plan`, so they're reviewable and repeatable. **Prefer them over running `terraform import` by hand for prod**

### Prevent it from happening again
- Harden the state backend: versioning + soft delete, `CanNotDelete` lock, least-privilege RBAC, Entra ID auth, private endpoint, diagnostic logs (code → [05 › section 6](05-Terraform_Security.md))
- Plus: storage account soft delete, keep state in a **separate subscription / RG**, **alerts** on blob delete, scheduled **state backups** to a second storage account, `prevent_destroy = true` on critical resources

---

## Quick Exam Traps
- `state rm` does **not** destroy the real resource
- `sensitive = true` does **not** encrypt state
- Backend block → **no variables** (use partial config / `-backend-config`)
- `terraform refresh` & `taint` are **deprecated**
- S3 backend `dynamodb_table` locking is **deprecated** → use `use_lockfile = true`
- `-refresh-only` changes **state only**, never infra
- Not every backend supports locking. Local, azurerm, s3, gcs and HCP Terraform do
- `terraform_remote_state` can only read **root-level outputs**
- `default` workspace can't be deleted
- CLI workspace (just a state file) ≠ HCP Terraform workspace (config + state + vars + permissions + runs)
- `.terraform.lock.hcl` → commit it. `*.tfstate` → don't
