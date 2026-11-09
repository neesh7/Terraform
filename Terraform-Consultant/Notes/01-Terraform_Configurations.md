# Terraform Configurations

## Terraform Blocks
Blocks are the building blocks of Terraform infrastructure code. Organizing configuration into blocks gives us:
1. A clear structure
2. Flexibility and modularity
3. Reusable patterns

## Block Types
| Block       | Purpose                                                       |
|-------------|---------------------------------------------------------------|
| `terraform` | Settings for Terraform itself (required version, providers, backend) |
| `provider`  | Configures the platform Terraform talks to (AWS, Azure, GCP...) |
| `resource`  | Defines an infrastructure object to create and manage        |
| `data`      | Reads information about existing infra without managing it   |
| `variable`  | Declares an input value for the configuration                |
| `output`    | Exposes a value after `apply` (or to a parent module)        |
| `module`    | Calls a reusable group of Terraform configuration            |
| `import`    | Brings existing infra under Terraform management             |

## Advanced Block Types
| Block       | Purpose                                                       |
|-------------|---------------------------------------------------------------|
| `locals`    | Defines named local values (computed once, reused in the module) |
| `moved`     | Records a resource rename/move so Terraform updates state instead of destroying and recreating it |
| `removed`   | Removes a resource from state without destroying the real infra (v1.7+) |
| `check`     | Runs validation assertions on infra; failures warn but don't block `apply` (v1.5+) |
| `ephemeral` | Fetches temporary values (e.g. secrets) that are never stored in state or plan (v1.10+) |

## Nested Blocks
These blocks live inside other blocks rather than at the top level.

| Block                | Lives Inside              | Purpose                                         |
|----------------------|---------------------------|-------------------------------------------------|
| `required_providers` | `terraform`               | Pins provider sources and versions              |
| `backend`            | `terraform`               | Configures where the state file is stored (S3, azurerm, gcs...) |
| `cloud`              | `terraform`               | Connects the configuration to HCP Terraform / Terraform Enterprise |
| `lifecycle`          | `resource`                | Controls create/destroy behaviour (`create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`) |
| `precondition` / `postcondition` | `lifecycle`, `data`, `output` | Custom checks before/after a resource is evaluated |
| `dynamic`            | `resource`, `data`, `provider`, `provisioner` | Generates repeated nested blocks from a collection |
| `provisioner`        | `resource`                | Runs scripts on create/destroy (`local-exec`, `remote-exec`, `file`) — use as a last resort |
| `connection`         | `resource`, `provisioner` | Defines SSH/WinRM details for remote provisioners |
| `validation`         | `variable`                | Adds custom rules for input values              |

## Test Blocks
Used in `.tftest.hcl` files with `terraform test` (v1.6+).

| Block      | Purpose                                                     |
|------------|-------------------------------------------------------------|
| `run`      | Runs a `plan` or `apply` and asserts on the result          |
| `assert`   | A condition (with error message) checked inside a `run` block |
| `mock_provider` | Replaces a real provider with fake data for tests (v1.7+) |

## Terraform Settings Block (`terraform {}`)
The `terraform` block configures **Terraform itself**: which CLI version, which providers and versions, and where state is stored. It is the main defence against version conflicts and state misconfiguration.

### Settings Inside It
| Setting | Purpose |
|---------|---------|
| `required_version` | Allowed Terraform CLI versions; runs fail if the installed CLI doesn't match |
| `required_providers` | Provider `source` and `version` constraint for each provider |
| `backend` | Where state is stored (`local`, `azurerm`, `s3`, `gcs`...) |
| `cloud` | Use HCP Terraform / Terraform Enterprise for state and runs |

### Rules (Avoid Misconfigurations)
- **Only literal values**: no variables, locals, resource attributes or functions inside the `terraform` block
- **One `backend` per configuration**; `backend` and `cloud` can't be used together
- No `backend` block means the `local` backend (`terraform.tfstate` in the working directory)
- Any change to `backend`, `cloud` or `required_providers` needs `terraform init` again
  - `terraform init -migrate-state`: move existing state to the new backend
  - `terraform init -reconfigure`: use the new backend and ignore existing state
- Keep secrets and per-environment values out of the backend block; pass them with `terraform init -backend-config="key=value"` or a file (**partial configuration**)
- Every module (including child modules) should declare its own `required_providers`; Terraform installs one version that satisfies **all** constraints, and fails if none does

### Avoiding Conflicts
1. **CLI version drift:** pin `required_version` (e.g. `">= 1.6, < 2.0"`) so everyone uses a compatible CLI
2. **Provider version drift:** pin versions in `required_providers` and commit `.terraform.lock.hcl`
3. **Concurrent runs:** use a remote backend that supports **state locking** (the azurerm backend locks with a blob lease); a stuck lock is released with `terraform force-unlock <LOCK_ID>`
4. **Environments overwriting each other:** use a unique state `key` (or workspace) per environment
5. **Lost or local-only state:** use a remote backend for team work, never commit `terraform.tfstate` to Git

### Example (`terraform.tf`)
```hcl
terraform {
  required_version = ">= 1.6, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate001"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"   # unique per environment
  }
}
```
**Exam points:** the `terraform` block can't use variables; changing the backend requires `terraform init`; the lock file pins **provider** versions, not the Terraform CLI version (that's `required_version`); not every backend supports locking; `-backend-config` enables partial configuration.

**Why the terraform block:** It makes the configuration reproducible. Every person and pipeline runs the same CLI range and provider versions against the same shared, locked state, so there are no "works on my machine" differences or overwritten state.

## Terraform Providers
A provider is a plugin that lets Terraform talk to a platform's API (AWS, Azure, GCP, Kubernetes...). Terraform core manages the workflow and state; the provider translates resources into API calls.

- Downloaded from the Terraform Registry during `terraform init`
- Each provider brings its own resource and data source types (e.g. `aws_instance`)
- Tiers: **Official** (HashiCorp), **Partner** (vendor), **Community**
- Source and version are pinned in `required_providers` inside the `terraform` block; settings like region go in the `provider` block
- Version constraints: `=` exact, `>=` minimum, `~>` allows only the rightmost part to increase (`~> 5.1` = 5.x, not 6.0)
- `alias` lets you configure the same provider more than once (e.g. multiple regions/accounts)
- Exact versions are locked in `.terraform.lock.hcl`; `terraform init -upgrade` updates them

### Example: Multiple Providers (`provider.tf`)
```hcl
locals {
  primary_region   = "centralindia"
  secondary_region = "eastus"
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Default provider (no alias)
provider "azurerm" {
  features {}                      # required by azurerm, even if empty
}

# Second configuration of the same provider
provider "azurerm" {
  alias = "secondary"
  features {}
}

resource "azurerm_resource_group" "primary" {
  name     = "rg-primary"
  location = local.primary_region  # uses the default provider
}

resource "azurerm_resource_group" "dr" {
  provider = azurerm.secondary     # <provider>.<alias>
  name     = "rg-dr"
  location = local.secondary_region
}
```
**Exam points:** a provider block without `alias` is the default; resources pick an aliased one with `provider = <name>.<alias>`; `azurerm` always needs a `features {}` block.

**Why multiple providers:** Each provider configuration is tied to one set of credentials and one target scope. To manage several accounts, subscriptions, tenants or (in AWS) regions from one configuration, you define aliased provider blocks and select them per resource with `provider = <name>.<alias>`.

### Best Practices
1. Always pin provider versions
2. Never hardcode credentials; use env variables, CLI profiles, or IAM roles
3. Commit `.terraform.lock.hcl` to version control
4. Configure providers only in the root module

## Terraform Resources
A resource block declares one infrastructure object (VM, VNet, storage account...) that Terraform creates, updates and destroys, and tracks in state.

- Syntax: `resource "<TYPE>" "<NAME>" { ... }`; the type prefix (`azurerm_`) tells Terraform which provider to use
- Address: `<TYPE>.<NAME>` (e.g. `azurerm_resource_group.main`); must be unique in a module
- **Arguments** are the values you set; **attributes** are values exported after creation (e.g. `id`), referenced as `<TYPE>.<NAME>.<ATTRIBUTE>`
- Referencing another resource creates an **implicit dependency**; use `depends_on` only for hidden dependencies Terraform can't see
- Changing some arguments updates in place (`~`); changing others forces replacement (`-/+`), shown in `terraform plan`

### Meta-Arguments (work on every resource type)
| Meta-Argument | Purpose |
|---------------|---------|
| `depends_on`  | Explicit dependency when no reference exists |
| `count`       | Creates N copies; address `type.name[0]` |
| `for_each`    | One copy per map/set item; address `type.name["key"]` |
| `provider`    | Picks a non-default (aliased) provider |
| `lifecycle`   | Changes create/update/destroy behaviour |

`count` / `for_each` details (rules, index problem, comparison) → [03 › section 4](03-Making-Code-Reusable.md).

### Explicit Dependency (`depends_on`)
`depends_on` tells Terraform that one resource must wait for another, even though it never **references** it. Use it only for **hidden dependencies** that Terraform can't see from the code.

```hcl
# Function App reads the storage account using its managed identity.
# Nothing in the function_app block references the role assignment,
# so Terraform could create both in parallel and the app would fail at startup.
resource "azurerm_role_assignment" "func_blob" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.func.principal_id
}

resource "azurerm_linux_function_app" "main" {
  # ...
  depends_on = [azurerm_role_assignment.func_blob]   # list of addresses, no quotes
}
```

- It takes a **list** of resource or module addresses: `depends_on = [azurerm_x.a, module.network]`
- It works on `resource`, `data`, `module` and `output` blocks
- It makes plans more **conservative**. Terraform waits, and data sources may be read only at apply time, so don't overuse it
- Terraform also follows the dependency **in reverse on destroy** (the dependent resource is destroyed first)

### Implicit vs Explicit Dependency
| | Implicit | Explicit |
|---|---|---|
| How | Referencing another resource's attribute (`azurerm_resource_group.main.name`) | The `depends_on = [...]` meta-argument |
| Detected by | Terraform, automatically from the expression | You, by declaring it manually |
| When to use | **Always preferred**, the default way | Only for hidden dependencies (IAM/role propagation, API side effects) |
| Example | Storage account uses `azurerm_resource_group.main.name` | Function App waits for a role assignment it never references |

**Exam points:** implicit dependencies come from references and are preferred; `depends_on` is a last resort for dependencies Terraform can't infer; its value is a list of addresses, not strings; both kinds appear in `terraform graph`.

### Lifecycle Options
| Option | Effect |
|--------|--------|
| `create_before_destroy` | Creates the replacement before destroying the old one |
| `prevent_destroy`       | Errors on any plan that would destroy the resource |
| `ignore_changes`        | Ignores drift on the listed arguments |
| `replace_triggered_by`  | Forces replacement when a referenced item changes |
| `precondition` / `postcondition` | Custom checks before/after the resource is planned/applied (TF 1.2+) |

### Lifecycle Meta-Argument (Details)
`lifecycle` is a **nested block inside a resource** that changes Terraform's **default create/update/destroy behaviour**.

By default, when an argument forces replacement, Terraform **destroys first, then creates** (`-/+`).

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-app-dev"
  location = "centralindia"

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
    ignore_changes        = [tags]
  }
}
```

**1. `create_before_destroy`**: creates the replacement first, then destroys the old one. The plan shows `+/-` instead of `-/+`
- Use it for zero-downtime replacement (e.g. a public IP or certificate)
- The new object must be able to exist alongside the old one, so **unique names** are needed. Use a `random` suffix or `name_prefix`, otherwise you get a name conflict
- It is passed on to the resources this one depends on

**2. `prevent_destroy`**: any plan that would destroy the resource **fails with an error**
- Use it to protect critical resources: databases, Key Vault, state storage
- It only works while the block **stays in the code**. If you delete the resource block, the protection goes with it and the resource is destroyed

**3. `ignore_changes`**: Terraform ignores changes to the listed arguments when it plans updates
```hcl
lifecycle {
  ignore_changes = [tags, tags["CreatedBy"]]   # specific args or map keys
  # ignore_changes = all                       # ignore every argument (create-only)
}
```
- Use it when something outside Terraform changes the value: Azure Policy adding tags, autoscale changing `instance_count`
- It lists **argument names**, not strings. A value is used only at **create** time

**4. `replace_triggered_by`** (TF 1.2+): forces **replacement** of this resource when a referenced resource or attribute changes
```hcl
resource "azurerm_linux_virtual_machine" "web" {
  # ...
  lifecycle {
    replace_triggered_by = [azurerm_network_interface.web.id]   # recreate the VM if the NIC is replaced
  }
}
```
- Only **resource addresses or their attributes** are allowed, not variables. For a variable, wrap it in a `terraform_data` resource

**5. `precondition` / `postcondition`** (TF 1.2+): custom checks with an `error_message`
```hcl
lifecycle {
  precondition {
    condition     = var.env != "prod" || var.replication == "GRS"
    error_message = "Prod storage must use GRS."
  }
  postcondition {
    condition     = self.primary_blob_endpoint != ""   # `self` = this resource (postcondition only)
    error_message = "Blob endpoint was not created."
  }
}
```
- `precondition` is checked **before** the resource is planned or applied. `postcondition` is checked **after**, and can use `self`
- A failure **stops** the run (unlike a `check` block, which only warns)

**Exam points:**
- `lifecycle` is a meta-argument and works on **every resource type**
- Its values must be **literals or static references**. You can't use variables or expressions in `create_before_destroy`, `prevent_destroy` or `ignore_changes`
- Default replacement is destroy-then-create. `create_before_destroy` reverses it
- `prevent_destroy` doesn't help if the resource block is deleted
- `ignore_changes = all` = manage the resource on create only

### Example (`main.tf`)
```hcl
locals {
  location = "centralindia"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-app"
  location = local.location
}

resource "azurerm_storage_account" "main" {
  name                     = "stappdata001"
  resource_group_name      = azurerm_resource_group.main.name  # implicit dependency
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    prevent_destroy = true
  }
}
```
**Exam points:** `terraform state list` shows resource addresses; provisioners are a last resort. (`count` vs `for_each` → 03; `depends_on` → above.)

**Why resource blocks:** Each resource block maps one real infrastructure object to a state entry, so Terraform can compare desired vs actual state and plan only the changes needed. Dependencies come from references, and Terraform uses them to build the graph that orders creation and runs independent resources in parallel.

## Terraform Data Sources
A data block **reads** information about infrastructure that already exists (or is managed elsewhere) so you can use it in your configuration. Terraform never creates, updates or destroys it.

- Syntax: `data "<TYPE>" "<NAME>" { ... }`; the arguments are filters/lookups (e.g. name, resource group)
- Reference: `data.<TYPE>.<NAME>.<ATTRIBUTE>` (note the `data.` prefix; resources have none)
- Provided by the same provider as resources (`azurerm_resource_group` exists as both a resource and a data source)
- Read during `plan`/`refresh`; deferred to `apply` if its arguments depend on values not known yet
- Supports meta-arguments `depends_on`, `count`, `for_each`, `provider`, and `lifecycle` (pre/postconditions only)
- Results are stored in state but `terraform destroy` does not touch the real object

### Common Use Cases
1. Use resources created manually or by another team/Terraform config (e.g. shared VNet, Key Vault)
2. Fetch current context (`azurerm_client_config` → tenant ID, subscription ID, object ID)
3. Look up dynamic values (latest image, available zones) instead of hardcoding them
4. Read secrets from Key Vault at run time

### Example (`data.tf`)
```hcl
data "azurerm_resource_group" "shared" {
  name = "rg-shared-network"            # existing RG, not managed here
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = "kv-app-001"
  location            = data.azurerm_resource_group.shared.location
  resource_group_name = data.azurerm_resource_group.shared.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}
```
**Exam points:** data sources are read-only and never change infrastructure; reference with the `data.` prefix; if the object doesn't exist, `plan` fails; they let one config consume another's resources (the alternative is `terraform_remote_state`, which reads another config's outputs).

**Why data sources:** They let a configuration depend on existing infrastructure without owning it, which avoids hardcoding IDs and keeps responsibility clear. Resources are what Terraform manages; data sources are what it only reads.

## Terraform Variables
A variable block declares an **input** to the configuration, so the same code can be reused across environments without editing it. Inside a module they act like function parameters.

- Syntax: `variable "<NAME>" { ... }`; reference as `var.<NAME>`
- If a variable has no `default` and no value is supplied, Terraform **prompts** for it interactively
- `default` must be a literal value; it cannot reference other variables, resources or functions
- Usually declared in `variables.tf`, with values supplied in `.tfvars` files

### Arguments
| Argument      | Purpose |
|---------------|---------|
| `type`        | Constrains the allowed value type |
| `default`     | Value used when none is supplied (makes the variable optional) |
| `description` | Documents the variable |
| `validation`  | Custom rule with `condition` and `error_message` |
| `sensitive`   | Hides the value in plan/apply output (**still stored in plain text in state**) |
| `nullable`    | `false` stops the variable being set to `null` |
| `ephemeral`   | Value is never written to state or plan (v1.10+) |

### Types
- **Primitive:** `string`, `number`, `bool`
- **Collection** (all elements the same type):
  - `list(...)`: ordered, duplicates allowed, index starts at `0` (`var.zones[0]`)
  - `map(...)`: key-value pairs, keys are always strings (`var.tags["env"]`)
  - `set(...)`: unordered, no duplicates, **cannot be indexed** (convert with `tolist()` first)
- **Structural** (mixed types): `object({...})`, `tuple([...])`
- `any`: accepts any type (Terraform infers it)

### Referencing Variables
| Type | How to reference |
|------|------------------|
| Primitive | `var.location` |
| List / tuple | `var.zones[0]` |
| Map | `var.tags["env"]` or `var.tags.env` |
| Object | `var.vm_config.size` |
| Inside a string | `"rg-${var.environment}"` (interpolation) |

- Use `var.name` directly when it's the whole value; `${...}` is only needed inside a string
- Variables **cannot** be used in the `backend` block or in another variable's `default`
- Splat expression on a list of objects: `var.vms[*].name` returns all names as a list

### Assigning Values & Precedence (Cheat Sheet)
If the same variable is set in several places, the **highest** number wins.

| Priority | Method | Example | Loaded automatically? |
|----------|--------|---------|-----------------------|
| 0 (lowest) | `default` in variable block | `default = "dev"` | Yes |
| 1 | Environment variable | `export TF_VAR_environment=dev` | Yes |
| 2 | `terraform.tfvars` | `environment = "dev"` | Yes |
| 3 | `terraform.tfvars.json` | `{"environment": "dev"}` | Yes |
| 4 | `*.auto.tfvars` / `*.auto.tfvars.json` | `prod.auto.tfvars` | Yes (alphabetical; later file wins) |
| 5 (highest) | `-var` / `-var-file` on CLI | `-var="environment=prod"` / `-var-file="prod.tfvars"` | No (must pass flag; last flag wins) |
| — | Interactive prompt | asked at `plan`/`apply` | Only if no value from any above |

**Remember:** CLI > `*.auto.tfvars` > `terraform.tfvars.json` > `terraform.tfvars` > `TF_VAR_` > `default`
- Any file not named `terraform.tfvars` or `*.auto.tfvars` (e.g. `dev.tfvars`) is **ignored** unless passed with `-var-file`
- `-var` and `-var-file` share the same level; whichever comes **later** on the command line wins
- Use `-input=false` in CI/CD pipelines so a missing value fails the run instead of waiting on a prompt

### Example (`variables.tf`)
```hcl
variable "location" {
  type        = string
  default     = "centralindia"
  description = "Azure region for all resources"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "admin_password" {
  type      = string
  sensitive = true
}
```
Set values in `terraform.tfvars`: `environment = "dev"`, or on the CLI: `terraform apply -var="environment=prod"`.

**Exam points:** know the precedence order (CLI flags win, `default` loses); `TF_VAR_` env variables are case-sensitive and match the variable name; `sensitive` does **not** encrypt state; only `terraform.tfvars` and `*.auto.tfvars` load automatically, any other `.tfvars` file needs `-var-file`.

**Why variables:** They separate configuration from values, so one codebase can deploy dev/test/prod by swapping `.tfvars` files. Use **variables** for values the caller provides and **locals** for values computed inside the module.

### Managing Variables Across Environments
Same code, different values (and a **separate state file**) per environment: per-env `.tfvars`, directory per env, CLI workspaces, HCP Terraform variable sets, or CI/CD `TF_VAR_*`. All five approaches → [00 › Managing Multiple Environments](00-Terraform_foundations.md). Workspaces in depth → [02](02-Terraform_State.md).

**Exam points:** a non-auto `.tfvars` file needs `-var-file`; `terraform.workspace` returns the current workspace name; variable sets are an HCP Terraform feature.

### Scope of Variables
Variables (and `locals`) are **module-scoped**. Root variables come from `.tfvars` / `-var` / `TF_VAR_` / `default`. Child module variables come **only** from the calling `module` block's arguments. Full isolation rules → [04 › section 4 Variable Isolation](04-Terraform_Modules.md).

## Terraform Outputs
An output block **exposes a value** from a module, like a function's return value. Root module outputs are printed after `apply`; child module outputs pass data back to the calling module.

- Syntax: `output "<NAME>" { value = ... }`; `value` is the only required argument
- Usually declared in `outputs.tf`
- Output values are stored in the **state file**
- Child module outputs are referenced as `module.<MODULE_NAME>.<OUTPUT_NAME>`
- Root module outputs can be read by another configuration through `terraform_remote_state`

### Arguments
| Argument      | Purpose |
|---------------|---------|
| `value`       | The value to expose (required) |
| `description` | Documents the output |
| `sensitive`   | Hides the value in plan/apply output (**still plain text in state**) |
| `depends_on`  | Explicit dependency (rarely needed) |
| `precondition`| Custom check before the output is saved |
| `ephemeral`   | Passes a value between modules without saving it to state (child modules only, v1.10+) |

### Commands
| Command | Result |
|---------|--------|
| `terraform output` | Lists all root outputs (sensitive ones shown as `<sensitive>`) |
| `terraform output <name>` | Shows one output (**reveals** a sensitive value) |
| `terraform output -json` | All outputs as JSON (**reveals** sensitive values) |
| `terraform output -raw <name>` | Plain string with no quotes, useful in scripts (strings, numbers, bools only) |
| `terraform output -json <name>` | One output as JSON (use for lists/maps/objects) |
| `terraform output -no-color` | Output without color codes, useful in pipeline logs |
| `terraform apply -refresh-only` | Updates state and output values to match real infra without changing resources |

### Example (`outputs.tf`)
```hcl
output "resource_group_id" {
  value       = azurerm_resource_group.main.id
  description = "ID of the main resource group"
}

output "storage_primary_key" {
  value     = azurerm_storage_account.main.primary_access_key
  sensitive = true
}
```
**Exam points:** `value` is required; if an output references a sensitive value without `sensitive = true`, Terraform errors; `sensitive` only hides CLI output, not state; `terraform output` reads from state, so run `apply` first; only **root** module outputs are shown in the CLI.

**Why outputs:** They make key values (IPs, IDs, endpoints) available to people, scripts, CI/CD pipelines, parent modules and other configurations. Variables are a module's inputs, outputs are its return values.

## Validation in Terraform (Custom Conditions)
Terraform has **4 ways** to enforce your own rules. Each one checks a different thing at a different time:

| Feature | Where | Checks | When | On failure |
|---|---|---|---|---|
| **Variable `validation`** | `variable` block | **Input values** | Start of plan, when the variable is evaluated | ❌ **Error**, run stops |
| **`precondition`** | `lifecycle` of `resource` / `data`, or inside `output` | Assumptions **before** the object is planned/applied | Before the object | ❌ **Error** |
| **`postcondition`** | `lifecycle` of `resource` / `data` | Guarantees **after** the object is created/read (`self`) | After the object | ❌ **Error** (blocks dependents) |
| **`check` block** (TF 1.5+) | Top-level block | **Overall health** of the infrastructure | End of every plan and apply | ⚠️ **Warning** only, run continues |

All four use the same structure:
```hcl
condition     = <expression that returns true or false>
error_message = "Full sentence explaining what is wrong."
```

---

### 1. Variable Validation
It checks **input values** before Terraform does anything else. This is the first line of defence against bad inputs.

```hcl
variable "env" {
  type = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "env must be dev, test or prod."
  }
}

variable "storage_name" {
  type = string
  validation {                                      # multiple validation blocks are allowed
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_name))
    error_message = "Storage name must be 3-24 lowercase letters or numbers."
  }
  validation {
    condition     = startswith(var.storage_name, "st")
    error_message = "Storage name must start with 'st'."
  }
}

variable "vnet_cidr" {
  type = string
  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))   # is it a valid CIDR?
    error_message = "vnet_cidr must be a valid CIDR, e.g. 10.0.0.0/16."
  }
}

variable "vm_count" {
  type = number
  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 5
    error_message = "vm_count must be between 1 and 5."
  }
}
```

- **Before TF 1.9**: the condition could reference **only the variable itself**
- **TF 1.9+**: it can also reference **other variables, locals and data sources**
  ```hcl
  condition = var.env != "prod" || var.replication == "GRS"   # cross-variable check (1.9+)
  ```
- Helpers: `can()` turns an error into `false`, and `try()` gives a fallback value. Others: `regex()`, `contains()`, `length()`, `alltrue()`, `anytrue()`
- For lists and maps: `alltrue([for s in var.subnets : can(cidrhost(s, 0))])`

---

### 2. Preconditions
They check **assumptions before** a resource, data source or output is evaluated. You can use them in `resource` / `data` (inside `lifecycle`) and in `output`.

```hcl
data "azurerm_resource_group" "shared" {
  name = var.shared_rg
}

resource "azurerm_storage_account" "main" {
  name                     = var.storage_name
  resource_group_name      = data.azurerm_resource_group.shared.name
  location                 = data.azurerm_resource_group.shared.location
  account_tier             = "Standard"
  account_replication_type = var.replication

  lifecycle {
    precondition {
      condition     = data.azurerm_resource_group.shared.location == "centralindia"
      error_message = "The shared RG must be in Central India (data residency rule)."
    }
    precondition {
      condition     = var.env != "prod" || var.replication == "GRS"
      error_message = "Prod storage must use GRS replication."
    }
  }
}

output "storage_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
  precondition {                                   # output blocks: precondition only
    condition     = azurerm_storage_account.main.https_traffic_only_enabled
    error_message = "Storage must enforce HTTPS before exposing its endpoint."
  }
}
```
- It **cannot** use `self`, because the object doesn't exist yet
- It can reference other resources, data sources, variables and locals
- **Use for:** rules that involve **several values** or **real infrastructure** (data sources), which variable validation (before 1.9) couldn't do

---

### 3. Postconditions
They check **guarantees after** a resource is created/updated or a data source is read. They're available in `resource` and `data` (inside `lifecycle`).

```hcl
data "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  resource_group_name = "rg-network"

  lifecycle {
    postcondition {
      condition     = contains(self.address_space, "10.0.0.0/16")
      error_message = "Hub VNet must use the 10.0.0.0/16 address space."
    }
  }
}

resource "azurerm_storage_account" "logs" {
  # ...
  lifecycle {
    postcondition {
      condition     = self.min_tls_version == "TLS1_2"     # self = this object
      error_message = "Storage account must enforce TLS 1.2."
    }
  }
}
```
- It **can use `self`** to refer to the object's own attributes
- If it fails, Terraform **stops** and resources that **depend on it are not created**. The object itself may already exist
- If an attribute is unknown until apply, Terraform checks the condition at **apply** time instead of plan

---

### 4. Check Blocks (TF 1.5+)
A `check` block is a top-level block that checks the **health of the whole infrastructure**. It **never blocks** a run. A failure only produces a **warning**.

```hcl
check "storage_https_only" {
  assert {
    condition     = azurerm_storage_account.main.https_traffic_only_enabled
    error_message = "Storage account allows plain HTTP traffic."
  }
}

# A scoped (nested) data source: it exists only inside this check
check "website_up" {
  data "http" "site" {
    url = "https://${azurerm_linux_web_app.main.default_hostname}"
  }

  assert {
    condition     = data.http.site.status_code == 200
    error_message = "Web app returned ${data.http.site.status_code}, expected 200."
  }
}
```
- It uses **`assert`** blocks (one or more), not `condition` directly
- It can contain **one scoped data source**. If that data source fails, you get a **warning**, not an error
- It runs at the end of **every `plan` and `apply`**
- **HCP Terraform:** check blocks power **continuous validation** (health assessments) that keep running between runs
- **Use for:** post-deployment smoke tests, certificate expiry, endpoint up/down. These are things you want to **know about**, not things that should **stop** a deploy

---

### Choosing the Right One
| Question | Use |
|---|---|
| Is the **input value** valid (format, allowed list, range)? | Variable `validation` |
| Is an **assumption true before** creating something (existing RG region, combination of values)? | `precondition` |
| Did the resource/data **turn out as expected** after create/read? | `postcondition` |
| Is the infrastructure **healthy overall**, warning only? | `check` block |
| Unit/integration tests in a separate file? | `terraform test` (`run` + `assert` in `.tftest.hcl`) |

### Order of Operations
```
terraform plan
 1. Variable validation      → root variables are checked first (child-module variables when that module is evaluated)
 2. For each object, in dependency (graph) order:
      a. precondition        → before the object is planned
      b. plan the change / read the data source
      c. postcondition       → after planning (if values are unknown until apply, deferred to apply)
 3. Output precondition      → when each output is evaluated
 4. check blocks             → at the END of the plan (warning only)

terraform apply
 0. (apply without a saved plan runs all the plan steps above first)
 1. Variable validation      → part of that plan (a saved plan already passed it)
 2. For each object, in dependency order:
      a. precondition        → re-checked before the change is applied
      b. create / update / destroy
      c. postcondition       → checked using real values (self); failure stops dependent resources
 3. Output precondition
 4. check blocks             → at the END of the apply (warning only)
```

| Step | Validation | Fails → |
|---|---|---|
| 1 | Variable `validation` | Error. Nothing is planned |
| 2 | `precondition` (resource/data) | Error. This object and its dependents are skipped |
| 3 | `postcondition` (resource/data) | Error. The object may already exist, but dependents are not created |
| 4 | `output` precondition | Error. The output is not saved |
| 5 | `check` → `assert` | ⚠️ Warning. Run completes |

- There is **no global "all preconditions first" phase**. Pre/postconditions run **per object** as Terraform walks the **dependency graph**, so independent objects can be checked in parallel
- Preconditions and postconditions run in **both plan and apply**. Check blocks also run at the end of **both**
- A **postcondition on a data source** is checked right after the read, so a resource that uses that data never gets planned if it fails

---

**Exam points:**
1. `validation` lives **inside a `variable` block**. You can have **multiple** validation blocks, and each needs `condition` + `error_message`
2. Before TF 1.9, a validation could reference **only its own variable**. From 1.9 it can reference other variables, locals and data sources
3. `precondition` and `postcondition` go **inside `lifecycle`** for resources and data sources. `output` blocks allow **only `precondition`**, and it's written directly in the output block
4. **`self`** is available **only in `postcondition`** (and in provisioners/connection), not in `precondition`
5. A failed validation, precondition or postcondition is an **error** that stops the run. A failed **`check`** is only a **warning**
6. `check` blocks use **`assert`**, can hold **one scoped data source**, and run on every plan and apply (TF 1.5+)
7. `can()` returns `true`/`false` instead of an error, so it's often used in conditions (`can(regex(...))`, `can(cidrhost(...))`)
8. `error_message` should be a full sentence (start with a capital letter, end with a period)

**Interview POV:**
> **Q: How do you stop bad deployments in Terraform?**
> In layers. Variable `validation` rejects bad inputs early. `precondition`s enforce rules about existing infrastructure and combinations of values. `postcondition`s guarantee the result. `check` blocks give non-blocking health warnings and continuous validation in HCP Terraform. On top of that, `terraform test` covers module tests, and policy as code (Sentinel/OPA, Azure Policy) covers org-wide rules.
