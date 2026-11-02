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

`count` and `for_each` cannot be used together in the same block.

### Lifecycle Options
| Option | Effect |
|--------|--------|
| `create_before_destroy` | Creates the replacement before destroying the old one |
| `prevent_destroy`       | Errors on any plan that would destroy the resource |
| `ignore_changes`        | Ignores drift on the listed arguments |
| `replace_triggered_by`  | Forces replacement when a referenced item changes |

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
**Exam points:** prefer `for_each` over `count` when items can be added or removed (removing from a `count` list shifts indexes and recreates resources); `depends_on` takes a list of resource addresses; `terraform state list` shows resource addresses; provisioners are a last resort.

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
