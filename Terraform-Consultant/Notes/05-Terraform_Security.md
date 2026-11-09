# Terraform Security

## 1. Why Secrets in Terraform Are Risky

### The Core Problem
Terraform **needs** secrets (DB passwords, API keys, client secrets, storage keys) to manage infrastructure, but those secrets can be **exposed in many places**.

| Risk | What happens |
|---|---|
| **Stored as plaintext** | Passwords, API keys and account numbers end up in files (state, plan, `.tfvars`) **unencrypted** |
| **Shared across teams** | Remote backends make state readable by everyone with backend access. CI logs and outputs are captured too |
| **Needs protection at every layer** | There are many exposure points, so you need many protections. First step: know **where** secrets appear |

### Example: a secret in `terraform.tfstate`
`sensitive = true` hides the value in CLI output, but **state still stores it in plain text**:
```json
{
  "outputs": {
    "database_password_output": {
      "value": "MySuperSecretPassword123!",     // ← plaintext
      "type": "string",
      "sensitive": true                         // ← only a flag, NOT encryption
    }
  },
  "resources": [
    {
      "type": "aws_db_instance",
      "instances": [
        { "attributes": { "password": "MySuperSecretPassword123!" } }   // ← plaintext
      ]
    }
  ]
}
```

### Where Sensitive Data Can End Up (4 places)
| Place | Where exactly | Why it's a risk |
|---|---|---|
| **1. State files** | `terraform.tfstate` (local **or** remote) and `.tfstate.backup` | Plaintext JSON with **every resource attribute**, including generated secrets (`random_password`, storage access keys) |
| **2. Logs & console** | `terraform plan` / `apply` output, **provider error messages**, **CI/CD build logs**, `TF_LOG=DEBUG` logs, `terraform output -json` | Values get printed to the screen and stored in log systems that many people can read |
| **3. Version control** | **Committed `.tfvars` files**, **hardcoded values in `.tf` files** | **Git history is permanent.** Deleting the line doesn't remove the secret from history (you must rotate it) |
| **4. Plan files** | Saved plans (`terraform plan -out=tfplan`) | Contain the **proposed changes with full values**, and are often stored as **CI/CD artifacts** |

```
 .tf / .tfvars ──► Git history (permanent)
       │
       ▼
 terraform plan ──► console + CI logs
       │
       ├──► tfplan file ──► CI artifacts
       ▼
 terraform apply ──► terraform.tfstate (local / remote backend)
```

**Exam points:**
1. The state file stores **all** values, secrets included, in **plain text**. Anyone with backend access can read them
2. Treat the **state file and saved plan files as secrets** themselves
3. The 4 exposure points are **state files, logs/console, version control and plan files**
4. A secret committed to Git must be **rotated**. Removing it from the file (or rewriting history) is not enough, because it may already be cloned or cached

---

## 2. Protecting Secrets in Your Configuration (Overview)
Each layer is stronger than the one before. Each one gets its own section below, and the side-by-side comparison is in the **Protection Quick Reference** (end of section 5).
```
Layer 1: sensitive variables        → hide on screen / logs             (section 3)
Layer 2: environment variables      → keep out of Git                   (section 4)
Layer 3: external secret sources    → keep out of Terraform code        (section 5)
Layer 4: ephemeral + write-only     → keep out of state & plan          (section 7)
   + always: secure the state file  → encrypted, access-controlled backend (section 6)
   + better creds: Vault dynamic / OIDC → no long-lived credentials     (section 8)
```

**Exam point:** no single technique is enough. Combine them, and always secure the state file because it can still hold the secret.

---

## 3. Hiding Secrets with Sensitive Variables and Outputs

### Example
```hcl
variable "db_password" {
  type      = string
  sensitive = true                  # mark the input as sensitive
}

resource "azurerm_mssql_server" "main" {
  name                         = "sql-app-dev-01"
  resource_group_name          = "rg-app-dev"
  location                     = "centralindia"
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.db_password   # shown as (sensitive value) in plan
}
```

```
$ terraform plan
  + administrator_login_password = (sensitive value)
```

### Sensitive Outputs
| Output type | Behaviour |
|---|---|
| **Regular output** | Value is **shown** after `apply` and in `terraform output` |
| **Sensitive output** (`sensitive = true`) | Value is **hidden** (`<sensitive>`) |
| **Both** | Still **accessible programmatically** or with **`terraform output <name>`** |

```hcl
output "database_endpoint" {
  description = "Database connection endpoint"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name   # regular → shown
}

output "database_password" {
  description = "Database password"
  value       = azurerm_mssql_server.main.administrator_login_password
  sensitive   = true                                                     # hidden (REQUIRED here, or Terraform errors)
}
```

```
$ terraform apply
Outputs:
database_endpoint = "sql-app-dev-01.database.windows.net"
database_password = <sensitive>

$ terraform output database_password        # reveals the real value
"MySuperSecretPassword123!"

$ terraform output -raw database_password   # plain string, for scripts
MySuperSecretPassword123!

$ terraform output -json                    # reveals ALL values, sensitive ones included
```
- **Programmatic access** also exposes it: a parent module (`module.db.database_password`), `terraform_remote_state` from another config, and anything reading the state
- So `sensitive` stops **accidental** exposure (screens, CI logs). It does not stop **deliberate** access by anyone who can run Terraform or read state

### What `sensitive` Does vs Doesn't Protect
| ✅ DOES protect | ❌ DOESN'T protect |
|---|---|
| Hides values in **`terraform plan`** output | Still stored in the **state file (plaintext)** |
| Hides values in **`terraform apply`** output | Still **visible if you open state directly** (`cat terraform.tfstate`, `terraform show -json`, `terraform state pull`) |
| Prevents values appearing in **logs** (CI/CD) | Still **transmitted to providers** (the API needs the real value) |
| **Redacts** values in error messages | Still in **saved plan files** |
| Works for **variables and outputs** | Still revealed by `terraform output <name>` / `-json` / `-raw` |

### How it behaves
- **Sensitivity spreads:** any expression that uses a sensitive value becomes sensitive too (`"Server=x;Pwd=${var.db_password}"` is redacted)
- **Output rule:** an output that references a sensitive value **must** set `sensitive = true`, otherwise you get the error `Output refers to sensitive values`
- **Provider-marked attributes:** some attributes are sensitive by default (e.g. `primary_access_key`, `random_password.result`), even if you didn't mark them
- **Functions:**
  - `sensitive(value)` marks any value as sensitive
  - `nonsensitive(value)` removes the mark (use carefully, e.g. for a hash or a non-secret part)
- In child modules, an output's sensitivity carries over to the parent

**Exam points:**
1. `sensitive = true` = **redaction in CLI output only**. It is **not encryption**. Values stay plaintext in state and plan files
2. An output that uses a sensitive value **must** be marked `sensitive`, or `plan` fails
3. `terraform output <name>` shows the real value of a sensitive output. `terraform output` (no name) shows `<sensitive>`

---

## 4. Keeping Secrets Out of Version Control with Environment Variables

### The Problem: Committing Secrets to Git
```hcl
# terraform.tfvars   ❌ DON'T DO THIS
db_password = "MyS3cr3tP@ssw0rd!"
db_username = "admin"
api_key     = "sk-abc123xyz789"
```
`terraform.tfvars` is loaded automatically, so it often gets committed, and then the secret sits in Git history forever (see section 1).

### The Solution: `TF_VAR_<name>` Environment Variables
Declare the variable **without a default**, and set its value in the environment:
```hcl
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true          # no default value needed
}
```
```bash
# Bash / Linux / macOS
export TF_VAR_db_password="MyP@ssw0rd!"
export TF_VAR_api_key="sk-abc123xyz"
terraform apply
```
```powershell
# PowerShell
$env:TF_VAR_db_password = "MyP@ssw0rd!"
terraform apply
```
- Terraform **automatically** reads `TF_VAR_db_password` → `var.db_password`. If it's unset and has no default, Terraform **prompts**. Use `-input=false` in CI so the run fails instead
- Providers read their **own** env vars (`ARM_*`, `AWS_*`, `TF_TOKEN_<host>`), so credentials never go in a `provider` block
- `TF_VAR_` mechanics (naming, complex types, unset, full env var list) → [00 › Environment Variables with the CLI](00-Terraform_foundations.md)

### In CI/CD
Store the secret in the pipeline's **secret store** (GitHub Actions secrets, Azure DevOps variable groups/Key Vault, HCP Terraform **sensitive workspace variables**) and expose it to the job as `TF_VAR_*` / `ARM_*`:
```yaml
# GitHub Actions
env:
  TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
  ARM_CLIENT_SECRET:  ${{ secrets.ARM_CLIENT_SECRET }}
```

### Benefits vs Limitation
| ✅ Benefits | ❌ Limitation |
|---|---|
| **Never stored in files** | Does **NOT keep secrets out of state**. The value is still saved in plaintext in `terraform.tfstate` |
| **Never committed to Git** | Visible in shell history (`export ...`) and the process environment. Clear them, or use a secrets manager |
| **Perfect for CI/CD pipelines** | |
| **Works with `sensitive = true`** (hidden in output too) | |

**Safety net:** a `.gitignore` covering `*.tfvars`, `*.tfstate*` and `.terraform/` → template in [00 › `.gitignore`](00-Terraform_foundations.md).

**Exam points:**
1. Env vars keep secrets **out of Git**, not **out of state**. Combine them with `sensitive = true` + a secure backend
2. `TF_VAR_` has the lowest precedence after `default` and only reaches **root module** variables (precedence → 01, isolation → 04)

---

## 5. Reading Secrets from External Sources

### The Best Practice: Don't Store Secrets in Terraform
```
 Secrets manager                       Terraform                   Cloud
(AWS Secrets Manager,  ◄── 1. Retrieve ──  [ TF ]  ── 2. Build ──►  (AWS / Azure / GCP)
 Azure Key Vault,             secrets                  infrastructure
 GCP Secret Manager,
 HashiCorp Vault)
```
| Benefit | Meaning |
|---|---|
| **Secrets managed by dedicated tools** | Vault / Key Vault are built for secrets (encryption, versioning, auditing) |
| **Centralized rotation and access control** | Rotate in one place. RBAC/policies decide who and what can read |
| **Reduced secrets in Terraform state** | Fewer secrets live in code and state (use ephemeral resources to keep them out of state completely) |
| **One source of truth for secrets** | Apps and Terraform read the same secret. No copies in `.tfvars` |

### AWS Secrets Manager
```hcl
# Read the secret from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db_pass" {
  secret_id = "production/database/password"
}

resource "aws_db_instance" "main" {
  identifier     = "mydb"
  engine         = "postgres"
  instance_class = "db.t3.micro"
  username       = "admin"
  password       = data.aws_secretsmanager_secret_version.db_pass.secret_string   # fetched at run time
}
```

### Azure Key Vault (same pattern)
```hcl
data "azurerm_key_vault" "kv" {
  name                = "kv-shared-prod-01"
  resource_group_name = "rg-security-prod"
}

data "azurerm_key_vault_secret" "sql_pwd" {
  name         = "sql-admin-password"
  key_vault_id = data.azurerm_key_vault.kv.id
}

resource "azurerm_mssql_server" "main" {
  name                         = "sql-app-prod-01"
  resource_group_name          = "rg-app-prod"
  location                     = "centralindia"
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = data.azurerm_key_vault_secret.sql_pwd.value
}
```
> The identity running Terraform needs **read access** to the secret (Key Vault RBAC role `Key Vault Secrets User`, or an access policy with `Get`).

### HashiCorp Vault
```hcl
provider "vault" {
  address = "https://vault.example.com:8200"   # token via the VAULT_TOKEN env var
}

data "vault_kv_secret_v2" "db" {
  mount = "secret"
  name  = "prod/database"
}

# use: data.vault_kv_secret_v2.db.data["password"]
```

### Key Points
- **Terraform reads the secret when it runs** (during plan/refresh, or at apply if the data source depends on unknown values)
- **The password is NOT in your `.tf` files** or `.tfvars`, so nothing secret goes to Git
- ⚠️ **It still ends up in state**: both the data source result and the resource attribute are stored in plaintext
- **It uses a provider for the target secrets manager** (`aws`, `azurerm`, `google`, `vault`), which needs its own auth (use env vars / managed identity / OIDC, never hardcoded)
- Secret values from these data sources are usually marked **sensitive** by the provider, so they're hidden in plan output

**Exam points:**
1. Best practice: **store secrets in a dedicated secrets manager** and read them at run time with a **data source**
2. Reading via a data source keeps secrets **out of code and Git**, but **NOT out of state** (fix: section 7)
3. Terraform needs **credentials for the secrets manager provider** too. Protect them with env vars/OIDC/managed identity

---

### Protection Quick Reference
| Technique | Protects Logs/Output? | Protects State? | Protects Git Commits? | Best For |
|---|:-:|:-:|:-:|---|
| **Sensitive variables** | ✅ Yes | ❌ No | ❌ No | Hiding output, marking intent |
| **Environment variables** | ✨ Partial | ❌ No | ✅ Yes | Local dev, CI/CD, keeping secrets out of files |
| **External sources** | ✨ Partial | ‼️ Reduces | ✅ Yes | Production secrets, centralized management |
| **Ephemeral + write-only** (section 7) | ✅ Yes | ✅ Yes | ✅ Yes | Keeping secrets out of state and plan (TF 1.10+/1.11+) |

- **"Partial"** for env vars and external sources: they're hidden only if the variable or attribute is also **sensitive**
- **"Reduces"** for external sources: secrets aren't in code, but data source values are **still written to state**. Only **ephemeral** values / write-only args keep them out completely

**Use them together:**
1. **Create environment vars** to get secrets **into** Terraform (`TF_VAR_*`, `ARM_*`)
2. **Store secrets in external sources** where possible (Key Vault, Vault, Secrets Manager)
3. **Use sensitive variables** to hide output
4. **Plus:** always protect the **state** itself (encrypted remote backend + RBAC + versioning)

---

## 6. Securing State Files

### The State File Problem
State holds the **complete resource configuration**, every secret included, as **plaintext JSON**, and it isn't encrypted unless you configure that yourself (example in section 1).

> State files **will** contain secrets. Your job is to protect **where they're stored** and **who can access them**.

### Why Local State is Risky
Local state is unencrypted on a laptop, easy to commit to Git, hard to share, and has no access control or audit log. Remote state fixes all of these. Full local vs remote table → [02 › Local vs Remote Backend](02-Terraform_State.md).

### Configuring Encrypted Remote State: AWS (S3) vs Azure (azurerm) ⭐
The backend blocks (`s3` with `encrypt` / `kms_key_id` / `use_lockfile`, and `azurerm` with `use_azuread_auth` / `use_oidc` / `use_msi`) are in [02 › Local vs Remote Backend](02-Terraform_State.md). How each protection maps between the two clouds:

| Protection | AWS (S3) | **Azure (Blob Storage)** |
|---|---|---|
| Encryption at rest | `encrypt = true` (SSE AES-256, encrypted **before** being written to S3) | **Always on** (SSE AES-256, Microsoft-managed keys). Nothing to set in the backend |
| Customer-managed keys | `kms_key_id` (KMS CMK) | **CMK in Key Vault** set on the **storage account** (`azurerm_storage_account_customer_managed_key`), plus optional **infrastructure (double) encryption** |
| State locking | `use_lockfile = true` (TF 1.10+; the `dynamodb_table` method is deprecated) | **Built in** via a **blob lease**. No extra setting needed |
| Access control | IAM policies (bucket + KMS) | **Azure RBAC**: `Storage Blob Data Contributor` (read/write) for the pipeline, `Storage Blob Data Reader` (read-only) for others. Use `use_azuread_auth = true` and **disable shared keys** |
| Network | Bucket policy / VPC endpoint | Storage **firewall**, **private endpoint**, `public_network_access_enabled = false` |
| Versioning / recovery | S3 versioning | **Blob versioning** + **soft delete** (blobs and containers) |
| Audit logging | CloudTrail | **Diagnostic settings** → Log Analytics (`StorageBlobLogs`) + Activity Log |
| Deletion protection | MFA delete / bucket policy | **Resource lock** (`CanNotDelete`) on the RG/storage account |

### Hardened State Storage Account (Azure bootstrap)
```hcl
provider "azurerm" {
  features {}
  storage_use_azuread = true          # needed when shared keys are disabled
}

resource "azurerm_storage_account" "tfstate" {
  name                              = "sttfstateprod01"
  resource_group_name               = azurerm_resource_group.tfstate.name
  location                          = "centralindia"
  account_tier                      = "Standard"
  account_replication_type          = "GRS"         # geo-redundant copy of state
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false         # force Entra ID / RBAC auth only
  allow_nested_items_to_be_public   = false         # no public blobs
  infrastructure_encryption_enabled = true          # double encryption at rest
  public_network_access_enabled     = false         # reach via private endpoint only (or use network_rules)

  blob_properties {
    versioning_enabled = true                       # recover older state versions
    delete_retention_policy           { days = 30 } # soft delete for blobs
    container_delete_retention_policy { days = 30 } # soft delete for containers
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# Only the pipeline identity can write state
resource "azurerm_role_assignment" "pipeline_state_rw" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.pipeline_principal_id
}

# Prevent accidental deletion of the state account
resource "azurerm_management_lock" "tfstate" {
  name       = "lock-tfstate"
  scope      = azurerm_storage_account.tfstate.id
  lock_level = "CanNotDelete"
}
```
> Optional extras: a **CMK** from Key Vault (`azurerm_storage_account_customer_managed_key`), a **diagnostic setting** that sends blob logs to Log Analytics, and a **private endpoint** for the `blob` sub-resource.

### Controlling Who Can Access State: Defense in Depth
```
 ┌──────────────────────┐  • Only authorized users/roles can read state
 │  IAM / RBAC Policies │  • Separate read vs write permissions
 ├──────────────────────┤  • Audit logging for all access
 │    State Locking     │  • Prevents concurrent modifications
 ├──────────────────────┤  • Lockfile for S3, built in for others (Azure blob lease)
 │   File Encryption    │  • KMS / Key Vault CMK for an extra encryption layer
 └──────────────────────┘  • Customer-managed keys for compliance + automatic key rotation
   Defense in Depth = Encryption + Access controls + Audit logging
```

### State File Security Checklist
- [ ] **Always use remote state** for production
- [ ] **Enable encryption at rest** (Azure: on by default, add a CMK for compliance)
- [ ] **Implement access controls** (RBAC, separate read/write, Entra ID auth, no shared keys)
- [ ] **Enable state locking** (Azure: automatic blob lease)
- [ ] Bonus: versioning + soft delete, private network access, audit logs, resource lock, `*.tfstate` in `.gitignore`

**Exam points:**
1. **Protect the backend**. Don't rely on `sensitive` to protect state
2. **Remote backends** give central storage, **encryption at rest**, **access control**, **locking** and **audit logs**. Local state gives none of these
3. **S3**: `encrypt = true` + `kms_key_id` + `use_lockfile = true`. **azurerm**: encryption is **automatic**, **locking is native** (blob lease)
4. **HCP Terraform** encrypts state at rest (Vault-backed) and controls access via workspace/team permissions

---

## 7. Keeping Secrets Out of State: Ephemeral Values & Write-only Arguments

> Even with layers 1-3 + encrypted state, **sensitive values still end up in state**. Ephemeral values + write-only arguments fix this.

### Ephemeral Values: Secrets That Don't Persist (TF 1.10+)
They exist **only in memory** during a Terraform operation and are **never written to state or plan files**. They're calculated fresh on every run and discarded right after use.
```hcl
variable "database_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
  ephemeral   = true     # omitted from state and plan files
}
```
- The value is also **redacted** in the Terraform CLI and the HCP Terraform UI

### Where CAN you use ephemeral values?
| ✅ Allowed in | |
|---|---|
| **Local values** | A local becomes ephemeral if it references an ephemeral value |
| **Provider blocks** | e.g. a provider token fetched at run time |
| **Ephemeral resources** | `ephemeral "<type>" "<name>" {}` |
| **Ephemeral variables** | `ephemeral = true` |
| **Ephemeral outputs** | `ephemeral = true` (**child modules only**, not the root) |
| **Provisioner / connection blocks** | e.g. an SSH password |
| **Write-only arguments** | `*_wo` arguments on managed resources (TF 1.11+) |

### Important restriction: NOT in normal resource arguments ❌
```hcl
resource "azurerm_mssql_server" "db" {
  administrator_login_password = var.db_password   # ephemeral → ERROR
}
```
```
Error: Invalid use of ephemeral value
  Ephemeral values are not valid in resource arguments,
  because resource instances must persist between Terraform phases.
```

### Ephemeral Resources (TF 1.10+)
- A **new block type** (not `data` or `resource`)
- **Fetches data at run time** and keeps it **in memory**
- **Never persisted** in state, and flushed when the Terraform operation completes
- **Opened and closed** during execution
```hcl
# Regular data source (stored in state)
data "azurerm_key_vault_secret" "db" {
  name         = "database-password"
  key_vault_id = var.key_vault_id
}

# Ephemeral resource (NOT stored in state)
ephemeral "azurerm_key_vault_secret" "db" {
  name         = "database-password"
  key_vault_id = var.key_vault_id
}
# reference: ephemeral.azurerm_key_vault_secret.db.value
```
**When to use one:** fetching secrets from **Vault / Key Vault**, reading **temporary credentials**, retrieving **dynamic tokens**.
> ⚠️ The **provider developer** decides which ephemeral resources exist and which arguments they take.

### Write-only Arguments (TF 1.11+)
They let you pass a **temporary (ephemeral) value** to a **managed resource** without saving it to **state or plan files**.
- Named with a **`_wo`** suffix, usually paired with **`_wo_version`**
- **Each provider defines** which write-only arguments exist on its resources
- Terraform **can't see** the stored value, so it can't detect changes. **Increment `_wo_version`** to push a new value (rotation)

```
 Key Vault / Vault ◄── 1. Retrieve secret (ephemeral resource) ── Terraform ── 2. Build infra (resource block) ──► Azure
                                                                   │  secret kept in RAM only
                                                                   └── 3. Does NOT write the secret to state
```

### Comparison
| Regular resource block | Write-only argument with version |
|---|---|
| `password = var.database_password` | `password_wo = var.ephemeral_pass` + `password_wo_version = 1` |
| ❌ Secret **would** be stored in state | ✅ Secret would **NOT** be stored in state |

### ⭐ Azure: Ephemeral + Write-only (password never touches state)
```hcl
# 1. Read the secret from Key Vault in memory only
ephemeral "azurerm_key_vault_secret" "sql_pwd" {
  name         = "sql-admin-password"
  key_vault_id = data.azurerm_key_vault.kv.id
}

# 2. Pass it to a write-only argument, so it is never saved to state
resource "azurerm_mssql_server" "main" {
  name                                    = "sql-app-prod-01"
  resource_group_name                     = "rg-app-prod"
  location                                = "centralindia"
  version                                 = "12.0"
  administrator_login                     = "sqladmin"
  administrator_login_password_wo         = ephemeral.azurerm_key_vault_secret.sql_pwd.value
  administrator_login_password_wo_version = 1   # bump to 2 when you rotate the secret
}
```
> **One-liner:** in azurerm, read the secret with an `ephemeral "azurerm_key_vault_secret"` block (or an `ephemeral = true` variable) and pass it to a `*_wo` argument (e.g. `administrator_login_password_wo`) with a `*_wo_version`, so the password exists only in memory and **never lands in the state or plan file**.

Generate a new password and store it in Key Vault, also without state:
```hcl
ephemeral "random_password" "sql" {      # random provider 3.7+
  length  = 24
  special = true
}

resource "azurerm_key_vault_secret" "sql_pwd" {
  name             = "sql-admin-password"
  key_vault_id     = data.azurerm_key_vault.kv.id
  value_wo         = ephemeral.random_password.sql.result
  value_wo_version = 1
}
```

**Exam points:**
1. **Ephemeral values** (TF **1.10+**) are never stored in **state or plan**. Mark them with `ephemeral = true` on variables/outputs, or use an `ephemeral` block
2. Ephemeral values can't go into **normal resource arguments**. Only locals, providers, provisioners/connections, other ephemeral blocks, ephemeral outputs (child modules) and **write-only args**
3. **Write-only arguments** (TF **1.11+**) end in `_wo`. Their value is **never** persisted, and you rotate them by incrementing `_wo_version`
4. Providers decide which **ephemeral resources** and **write-only arguments** exist
5. Ephemeral resources are referenced as `ephemeral.<TYPE>.<NAME>.<ATTR>`

---

## 8. Working with HashiCorp Vault: Dynamic Credentials

### The Problem with Static Credentials
**Traditional approach:** locally stored credentials → Terraform → manages infrastructure (Azure / GCP / AWS)
- Terraform users get their **own, long-lived credentials** (e.g. an SP client secret valid for 1-2 years)
- They're **stored locally** on machines/laptops (security risk)
- They're **difficult to rotate, revoke and audit**
- **Large attack surface**, because they're **highly privileged** (often Owner/Contributor on a whole subscription)

### Dynamic Credential Generation (Vault)
```
            ③ Return temporary credentials (with a TTL)
      ┌──────────────────────────────────────────┐
      ▼                                          │
 [Terraform] ── ① Identity-based auth ──►  [ Vault ] ── ② Generate credentials ──► Azure / GCP / AWS
      │                                                                              ▲
      └──────────────────── ④ Deploy / manage infrastructure ────────────────────────┘
```
1. **Identity-based authentication:** Terraform (or the CI job) logs in to Vault with its **identity** (JWT/OIDC from GitHub Actions or Azure DevOps, Azure managed identity, AppRole). No cloud secret is stored
2. **Generate credentials:** Vault's **secrets engine** creates a **brand-new** credential in the cloud on demand (Azure: a new SP / client secret)
3. **Return temporary credentials:** with a **lease + TTL**
4. **Deploy/manage infrastructure** with those creds. When the TTL expires, **Vault revokes them automatically** (deletes the SP/secret)

### TTL & Leases
Every dynamic secret comes with a **lease**: Vault tracks it and kills it when time is up.
| Term | Meaning |
|---|---|
| **`ttl`** | Default lifetime of the credential (e.g. `15m`, `1h`) |
| **`max_ttl`** | Hard upper limit. A lease can be **renewed** up to this, never beyond |
| **Lease ID** | Handle used to **renew** (`vault lease renew <id>`) or **revoke** early (`vault lease revoke <id>`) |
| **Auto-revoke** | When the TTL expires, Vault **deletes the credential in the cloud** (e.g. removes the SP) |
| **Revoke by prefix** | `vault lease revoke -prefix azure/creds/tf-dev`, a kill switch for every credential from one role (incident response) |

> Pick a TTL **slightly longer than your longest `apply`**, e.g. `ttl = 30m`, `max_ttl = 1h`. If it expires mid-apply, the run fails.

### Limited-Scope Credentials (least privilege)
Scope is controlled in **two places**:
1. **Vault role** → **what the generated credential can do** in the cloud (which role, at which scope)
2. **Vault policy** → **who can request** that role
```
 dev pipeline  ──(policy allows)──►  azure/creds/tf-dev   → Contributor on rg-app-dev only,  ttl 30m
 prod pipeline ──(policy allows)──►  azure/creds/tf-prod  → Contributor on rg-app-prod only, ttl 30m
 dev pipeline  ──(policy DENIES)──✕  azure/creds/tf-prod
```

### Example: Vault Azure Secrets Engine (set up once, by the Vault/platform team)
```hcl
# Vault is given ONE privileged SP that can create other SPs (only Vault knows this secret)
resource "vault_azure_secret_backend" "azure" {
  path            = "azure"
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.vault_sp_client_id
  client_secret   = var.vault_sp_client_secret
}

# Role = what the generated credentials can do + how long they live
resource "vault_azure_secret_backend_role" "tf_dev" {
  backend = vault_azure_secret_backend.azure.path
  role    = "tf-dev"
  ttl     = "30m"          # default lifetime
  max_ttl = "1h"           # hard limit

  azure_roles {
    role_name = "Contributor"
    scope     = "/subscriptions/${var.subscription_id}/resourceGroups/rg-app-dev"   # one RG only
  }
}

# Policy = who can ask for that role
resource "vault_policy" "tf_dev" {
  name   = "tf-dev"
  policy = <<-EOT
    path "azure/creds/tf-dev" {
      capabilities = ["read"]
    }
  EOT
}
```

### Example: Terraform consuming dynamic Azure credentials
```hcl
provider "vault" {
  address = "https://vault.example.com:8200"   # auth via VAULT_TOKEN / JWT login in CI
}

# Each run gets a brand-new SP that expires after the TTL
data "vault_azure_access_credentials" "creds" {
  backend        = "azure"
  role           = "tf-dev"
  validate_creds = true       # wait until Azure AD has propagated the new SP
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = data.vault_azure_access_credentials.creds.client_id
  client_secret   = data.vault_azure_access_credentials.creds.client_secret
}
```

### The Vault Provider Workflow (ephemeral, best pattern)
```hcl
# ① Terraform authenticates to Vault with its identity
provider "vault" {
  address = "https://vault.example.com:8200"
  # <identity-based authentication config>  e.g. auth_login_jwt { role = "tf-ci" } in CI
}

# ② Vault generates temporary cloud credentials, kept in memory only
ephemeral "vault_aws_access_credentials" "creds" {
  backend = vault_aws_secret_backend.aws.path
  role    = vault_aws_secret_backend_role.example.name
  type    = "creds"
  region  = "us-east-1"
}

# ③ The cloud provider is configured with the ephemeral creds (allowed: provider blocks accept ephemeral values)
provider "aws" {
  region     = "us-east-1"
  access_key = ephemeral.vault_aws_access_credentials.creds.access_key
  secret_key = ephemeral.vault_aws_access_credentials.creds.secret_key
}

# ④ Resources are provisioned with the temporary credentials
resource "aws_instance" "main" {
  # ...
}
```
Chain: **Vault provider (identity auth) → ephemeral credentials (e.g. valid 120 s, auto-revoked) → cloud provider → resources**
- For Azure, use the same pattern as the data-source example above, swapping `data` for `ephemeral` if your Vault provider version has an ephemeral Azure credentials resource

| | `data "vault_..._credentials"` | `ephemeral "vault_..._credentials"` |
|---|---|---|
| Creds generated per run | ✅ | ✅ |
| Short TTL + auto-revoke | ✅ | ✅ |
| Stored in state/plan | ❌ **Yes**, plaintext | ✅ **No**, memory only |
| Terraform version | Any | **1.10+** |

### Summary: Why Use Vault for Terraform
| Benefit | What it gives you |
|---|---|
| **Centralized secret management** | **One place** to manage platform credentials. **Easy to rotate** the few long-lived credentials Vault itself holds |
| **Reduced attack surface** | Credentials **expire automatically**. Compromised creds are **only valid for minutes**. Each Vault role is **least-privilege** |
| **Auditable** | Every credential request is logged in Vault's audit log against an identity. Unique creds per run, so nobody shares a key |
| **No local credential storage** | Developers **never touch** cloud credentials (AWS keys / Azure SP secrets). **No credential redistribution** (no sharing over chat/email, nothing on laptops) |

### Related: dynamic credentials without Vault
| Option | How |
|---|---|
| **OIDC / workload identity federation** | GitHub Actions or Azure DevOps gets a short-lived token from Entra ID. azurerm uses `use_oidc = true` (`ARM_USE_OIDC`). **No secret at all** |
| **Managed identity** | Self-hosted runner/VM in Azure → `use_msi = true` (`ARM_USE_MSI`) |
| **HCP Terraform dynamic provider credentials** | The workspace trusts Azure/AWS/GCP (or Vault) via OIDC. Set `TFC_AZURE_PROVIDER_AUTH = true` + `TFC_AZURE_RUN_CLIENT_ID` |

**Exam points:**
1. **Static credentials** are long-lived, stored locally, hard to rotate/revoke/audit and highly privileged. Avoid them
2. **Vault dynamic secrets** are **generated on demand**, **short-lived (TTL)** and **automatically revoked** when the lease expires
3. `ttl` = default lifetime. `max_ttl` = maximum, even with renewals. Leases can be **renewed** or **revoked early**
4. **Least privilege**: the Vault **role** limits what the credential can do, and the Vault **policy** limits who can get it
5. Terraform authenticates to Vault with an **identity** (OIDC/JWT, AppRole, cloud identity), not a stored cloud key
6. HCP Terraform supports **dynamic provider credentials** (OIDC) for Azure/AWS/GCP/Vault

### Interview POV
> **Q: How do you avoid long-lived cloud credentials in Terraform pipelines?**
> Use identity-based, short-lived credentials. Either OIDC workload identity federation from the pipeline to Entra ID (`use_oidc`, no secret), or Vault's Azure secrets engine. There, the pipeline logs in to Vault with its JWT, gets a per-run SP scoped to one RG with a 30-minute TTL, and Vault revokes it automatically. Everything is audited, nothing is stored on laptops, and a leak expires on its own.

---

## 9. Debugging Terraform (`TF_LOG`)

### Why would you need detailed logs?
- Investigating **unexpected Terraform behavior**
- Preparing **bug reports** for HashiCorp or provider teams
- Understanding exactly **what Terraform is doing under the hood** (API calls, graph walk, provider plugin calls)

### The `TF_LOG` Environment Variable
Setting `TF_LOG` enables detailed logging for every following command:
```bash
export TF_LOG=TRACE                    # Linux / macOS / Bash
export TF_LOG_PATH=./terraform.log     # optional: write to a file instead of stderr
terraform plan                         # <detailed logs>
unset TF_LOG TF_LOG_PATH               # turn it off again
```
```powershell
$env:TF_LOG = "TRACE"                  # Windows PowerShell
$env:TF_LOG_PATH = ".\terraform.log"
terraform plan
Remove-Item Env:TF_LOG, Env:TF_LOG_PATH
```

### Log Levels (most → least verbose)
```
 JSON ──► TRACE ──► DEBUG ──► INFO ──► WARN ──► ERROR
 most verbose (detailed)                    less verbose
```
| Level | Meaning |
|---|---|
| `JSON` | Same detail as **TRACE**, but each line is **JSON** (machine-readable, for log tools) |
| `TRACE` | **Most** detailed: every step, including full provider API requests/responses |
| `DEBUG` | Detailed internal operations, less noisy than TRACE |
| `INFO` | General progress messages |
| `WARN` | Only warnings |
| `ERROR` | Only errors |
- Any **other / invalid value** (e.g. `TF_LOG=1`) falls back to **TRACE**. `TF_LOG=OFF` (or unset) disables logging
- The full logging env var table is in [00 › Environment Variables with the CLI](00-Terraform_foundations.md)

### Separate Core and Provider Logging
| Variable | Logs | Use it to |
|---|---|---|
| `TF_LOG_CORE=TRACE` | **Terraform Core only** (graph, state, plan logic) | Provide logs to the **Terraform core team** (support) |
| `TF_LOG_PROVIDER=TRACE` | **Providers only** (e.g. azurerm API calls) | Offer logs to the **provider developers** to troubleshoot bugs |
- Both take the **same level arguments** as `TF_LOG` (`TRACE`, `DEBUG`, `INFO`, ...)
- They can be set independently, e.g. `TF_LOG_CORE=WARN` + `TF_LOG_PROVIDER=TRACE` to see only provider detail (useful for azurerm API errors)

### Saving Logs to a File (`TF_LOG_PATH`)
```bash
export TF_LOG=TRACE
export TF_LOG_PATH=terraform.log
```
- `TF_LOG` (**or** `TF_LOG_CORE` / `TF_LOG_PROVIDER`) **must also be set**. `TF_LOG_PATH` alone does nothing
- Logs are **appended** to the file (it isn't overwritten each run, so delete it between runs for a clean log)
- The file is **created automatically** if it doesn't exist

### Turning Logging Off (unset)
`export` / `$env:` keep the variable for the **whole shell session**, so every later command keeps logging (slow, noisy, and may leak secrets) until you unset it:
```bash
unset TF_LOG TF_LOG_CORE TF_LOG_PROVIDER TF_LOG_PATH       # Bash / Linux / macOS
TF_LOG=TRACE terraform plan                                # or: set it for ONE command only, nothing to unset
```
```powershell
Remove-Item Env:TF_LOG, Env:TF_LOG_PATH -ErrorAction SilentlyContinue   # PowerShell
```
- `TF_LOG=OFF` also disables logging, but **unset** is cleaner (nothing left in the environment)
- Closing the terminal clears it too, **unless** you put it in `~/.bashrc` / `$PROFILE`, so never add `TF_LOG` there

- **Crash:** if Terraform itself panics, it writes **`crash.log`** to the working directory (attach it to a bug report; it's in the standard `.gitignore`)

### ⚠️ Security note
`TRACE`/`DEBUG` logs can include **request bodies, tokens and secret values** (`sensitive` doesn't apply to provider debug output). This is the "logs & console" exposure point from section 1:
- Turn logging on only while debugging, then **unset** it
- **Never** enable `TF_LOG` permanently in CI/CD, and don't upload log files as public artifacts
- Review and **redact** logs before attaching them to a GitHub issue or bug report

**Exam points:**
1. `TF_LOG` enables detailed logs. Levels from most to least verbose: **TRACE > DEBUG > INFO > WARN > ERROR** (`JSON` = TRACE in JSON format)
2. `TF_LOG_PATH` writes logs to a file but **only works when `TF_LOG` (or `TF_LOG_CORE` / `TF_LOG_PROVIDER`) is also set**. Without a path, logs go to **stderr**. The file is **appended to** and created if missing
3. `TF_LOG_CORE` = core-only logs (for HashiCorp support), `TF_LOG_PROVIDER` = provider-only logs (for provider developers). Both take the same levels
4. An invalid `TF_LOG` value defaults to **TRACE**
5. A Terraform panic writes **`crash.log`**
