# Terraform Modules

## 1. What is a Module?

A **module** is a group of `.tf` files kept together in **one directory**. Every Terraform configuration is a module.

| Term | Meaning |
|---|---|
| **Root module** | The directory where you run `terraform plan/apply`. Every configuration has exactly **one** |
| **Child module** | A module that another module calls with a `module` block |
| **Published module** | A module shared through the Public or Private **Terraform Registry** |

```
project/
├── main.tf              # root module, calls the child module
├── variables.tf
├── outputs.tf
└── modules/
    └── storage/         # child module
        ├── main.tf
        ├── variables.tf # inputs to the module
        └── outputs.tf   # values the module returns
```

```hcl
# Root module calling a child module
module "storage" {
  source   = "./modules/storage"   # required: where the module lives
  name     = "stappdev001"         # passed to the module's input variables
  location = "eastus"
}
```

A module works like a **function**:
- **input variables** are its arguments
- **resources** are its body
- **outputs** are its return values

---

### Benefits of Modules
| Benefit | What it means |
|---|---|
| **Reusability** | Write once, then call it many times (dev/test/prod, many regions) without copy-pasting |
| **Organization** | Splits a large configuration into small, logical pieces (network, compute, storage) |
| **Encapsulation** | Hides complexity. The caller passes only inputs and doesn't need to know the internal resources |
| **Consistency & Standards** | Teams use the same approved, tested pattern (naming, tags, security settings) |
| **Fewer errors** | Tested code is reused instead of rewritten, which means fewer mistakes |
| **Versioning** | Registry and Git modules can be pinned to a version, so updates are controlled |
| **Collaboration** | Teams can own and publish modules for others to use (Private Registry) |

---

## Important Points (Exam)
1. **Every** Terraform configuration has a **root module**, even one with a single `main.tf`
2. A module is defined by its **directory**, not by a file. Terraform loads every `.tf` file in that folder
3. `source` is the **only required** argument in a `module` block
4. After you add or change a module, run **`terraform init`** (or `terraform get`) to download or install it
5. A child module **cannot read** the parent's variables or resources directly. Data goes in only through **input variables** and comes out only through **outputs**
6. Read a module's output with `module.<MODULE_NAME>.<OUTPUT_NAME>`

---

### Interview POV
> **Q: Why use modules?**
> To get **DRY** (Don't Repeat Yourself) infrastructure. One tested module, such as a VNet or AKS cluster, is reused across environments with different inputs. This gives consistency, version control and easier maintenance.

> **Q: Root vs child module?**
> The root module is where you run Terraform. A child module is called from it with a `module` block.

---

## 2. Implementing a Module

### Step 1: Create the child module (`modules/storage/`)
```hcl
# modules/storage/variables.tf  (inputs)
variable "name"     { type = string }
variable "rg_name"  { type = string }
variable "location" {
  type    = string
  default = "eastus"         # optional input (has a default)
}
```

```hcl
# modules/storage/main.tf  (resources)
resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

```hcl
# modules/storage/outputs.tf  (return values)
output "storage_id" {
  value = azurerm_storage_account.this.id
}
```

> The child module has **no `provider` block**. It inherits the provider from the root. It declares only `required_providers` if needed.

### Step 2: Call it from the root module
```hcl
# main.tf (root)
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-app-dev"
  location = "eastus"
}

module "storage_dev" {
  source   = "./modules/storage"
  name     = "stappdev001"
  rg_name  = azurerm_resource_group.rg.name
}

module "storage_prod" {               # same module, reused
  source   = "./modules/storage"
  name     = "stappprod001"
  rg_name  = azurerm_resource_group.rg.name
  location = "westeurope"
}

output "dev_storage_id" {
  value = module.storage_dev.storage_id   # module.<NAME>.<OUTPUT>
}
```

### Step 3: Init and apply
```bash
terraform init      # installs modules into .terraform/modules/
terraform plan
terraform apply
```

Resource addresses in state include the module path:
```
module.storage_dev.azurerm_storage_account.this
module.storage_prod.azurerm_storage_account.this
```

### Calling a Registry module
```hcl
module "vnet" {
  source  = "Azure/vnet/azurerm"   # <NAMESPACE>/<NAME>/<PROVIDER>
  version = "4.1.0"

  resource_group_name = azurerm_resource_group.rg.name
  vnet_location       = "eastus"
  use_for_each        = true
}
```

---

## 3. Module Versioning

**Module versioning** pins a module to a specific release, so your code doesn't break when the module author publishes changes.

### Where you can set a version
| Source type | How to version | Example |
|---|---|---|
| **Terraform Registry** (public/private) | `version` argument | `version = "~> 4.1"` |
| **Git / GitHub** | `?ref=` in the `source` URL (tag, branch, commit) | `source = "git::https://github.com/org/mod.git?ref=v1.2.0"` |
| **Local path** (`./modules/x`) | **Not supported.** Local modules use whatever code is on disk | - |

### Version constraint operators
| Operator | Meaning | Example `"..."` | Allows |
|---|---|---|---|
| `=` (or none) | Exact version | `"4.1.0"` | only 4.1.0 |
| `!=` | Exclude a version | `"!= 4.1.1"` | anything except 4.1.1 |
| `>`, `>=`, `<`, `<=` | Comparison | `">= 4.0, < 5.0"` | 4.x |
| `~>` | **Pessimistic**: only the **rightmost** number can increase | `"~> 4.1.0"` | 4.1.x (not 4.2) |
| | | `"~> 4.1"` | 4.x, where x ≥ 1 (not 5.0) |

```hcl
module "vnet" {
  source  = "Azure/vnet/azurerm"
  version = "~> 4.1"      # accept new 4.x releases, never 5.0
}

module "network" {
  source = "git::https://github.com/myorg/tf-network.git?ref=v1.2.0"   # Git tag
}
```

> Versions follow **Semantic Versioning**: `MAJOR.MINOR.PATCH`
> - **MAJOR**: breaking changes
> - **MINOR**: new features, backward-compatible
> - **PATCH**: bug fixes

### Upgrading a module version: `terraform init -upgrade`
```bash
# change version = "~> 5.0" in code, then:
terraform init -upgrade   # downloads the newest version allowed by the constraint
```

**Why `-upgrade` is needed:** a plain `terraform init` **reuses** what is already installed. It doesn't check for newer versions as long as the installed one still matches the constraint.

| Command | Modules | Providers |
|---|---|---|
| `terraform init` | Installs missing modules. Keeps already-installed versions in `.terraform/modules/` | Installs the versions recorded in `.terraform.lock.hcl` |
| `terraform init -upgrade` | Re-checks and downloads the **newest version allowed** by `version` / `?ref=` | Ignores the locked versions, picks the newest allowed by `required_providers`, and **updates `.terraform.lock.hcl`** |

```hcl
module "vnet" {
  source  = "Azure/vnet/azurerm"
  version = "~> 4.1"     # installed: 4.1.0, latest available: 4.3.0
}
```
```bash
terraform init            # stays on 4.1.0 (it already satisfies ~> 4.1)
terraform init -upgrade   # moves to 4.3.0 (newest allowed 4.x)
```

Key points:
- `-upgrade` **never goes beyond your constraint**. `~> 4.1` will never pull 5.0. To go to a new MAJOR version, change the constraint first
- It **only downloads** code. Nothing changes in your infrastructure until you `plan` and `apply`
- After upgrading, always run **`terraform plan`** to see what the new version changes
- Commit the updated **`.terraform.lock.hcl`** (because it records the provider upgrades)
- Use **`terraform get -update`** to update modules only (no providers, no backend)
- The flag has a **single dash**: `terraform init -upgrade` (Terraform also accepts `--upgrade`)

---

## Important Points (Exam)
1. The **`version` argument works only for Registry modules**. For Git, use `?ref=`. Local paths can't be versioned
2. If you leave out `version`, Terraform downloads the **latest** version, which is risky in production. Always pin
3. `~> 1.2.0` allows `1.2.x` only. `~> 1.2` allows `1.x` (≥1.2)
4. Run **`terraform init`** after adding a module or changing `source`. A plain `init` does **not** upgrade already-installed modules or providers. Use **`terraform init -upgrade`** to move to the newest version allowed by the constraint (this also updates `.terraform.lock.hcl` for providers)
5. The **`.terraform.lock.hcl` file locks provider versions only, NOT module versions**
6. Public Registry module naming: `terraform-<PROVIDER>-<NAME>` (repo name), called as `<NAMESPACE>/<NAME>/<PROVIDER>`
7. Child modules should not have a `provider` block. They inherit providers from the root

### Interview POV
> **Q: How do you make sure a module update doesn't break prod?**
> Pin modules with `version` (Registry) or `?ref=<tag>` (Git) and follow SemVer. Upgrade in dev first with `terraform init -upgrade` and review the `plan`, then promote the same version to prod.

---

## 4. Variable Isolation (Module Scope)

Each module has its **own separate namespace**. Variables, locals, resources and data sources declared in one module are **not visible** in any other module, whether parent or child.

```
 Root module                          Child module
┌────────────────────┐   inputs    ┌────────────────────┐
│ var.env            │ ──────────► │ var.name           │
│ local.tags         │  (arguments │ var.tags           │
│ azurerm_rg.rg      │   in module │ local.x  (private) │
│                    │   block)    │ resource ... this  │
│ module.st.st_id    │ ◄────────── │ output "st_id"     │
└────────────────────┘   outputs   └────────────────────┘
```

**Data goes in only through input variables and comes out only through outputs.**

### Example
```hcl
# root: variables.tf
variable "env" { default = "dev" }

# root: main.tf
module "storage" {
  source = "./modules/storage"
  name   = "stapp${var.env}001"   # pass the root var in explicitly
  tags   = { env = var.env }
}
```

```hcl
# modules/storage/main.tf
resource "azurerm_storage_account" "this" {
  name = var.name        # OK: declared in modules/storage/variables.tf
  tags = var.tags        # OK
  # env = var.env        # ERROR: "Reference to undeclared input variable"
                         #        var.env exists only in the root module
}
```

### Isolation rules
| Item | Scope | How to share it |
|---|---|---|
| `variable` | Only the module that declares it | Parent passes values as **arguments** in the `module` block |
| `locals` | Only the module that declares them (private) | Expose through an `output` if needed |
| `resource` / `data` | Only the module that declares them | Expose attributes through an `output` |
| `output` (child) | Readable **only by the direct parent** as `module.<NAME>.<OUTPUT>` | Re-export it with an `output` in the parent to go higher |
| `provider` | **Exception:** inherited by child modules by default | Or pass explicitly with the `providers = {}` argument |

### Inputs: required vs optional
```hcl
# modules/storage/variables.tf
variable "name" {
  type = string              # no default: REQUIRED, caller must pass it
}

variable "location" {
  type    = string
  default = "eastus"         # has default: OPTIONAL
}
```
- If the caller leaves out a required input, you get the error **`Missing required argument`**
- If the caller passes an argument the module doesn't declare, you get the error **`Unsupported argument`**

### Setting values: root only
`-var`, `-var-file`, `*.tfvars`, `*.auto.tfvars` and `TF_VAR_*` environment variables set **root module variables only**. You **can't** set a child module's variable directly from the CLI. Pass it through the root:
```
TF_VAR_env=prod  ──►  root var.env  ──►  module "storage" { name = "st${var.env}" }  ──►  child var.name
```

### Benefits of isolation
- **No name collisions.** Both the root and the child can have a `var.name`, and they are different variables
- **Clear contract.** The module's `variables.tf` and `outputs.tf` act as its public interface (API)
- **Safe reuse.** A module behaves the same wherever it is called, because it depends only on its inputs

---

## Important Points (Exam)
1. A child module **cannot** reference the parent's `var.`, `local.` or resources. Pass them in as **module arguments**
2. A parent can read only a child's **outputs** (`module.<NAME>.<OUTPUT>`), never its resources or locals directly
3. Outputs reach **only one level up**. A grandparent needs the middle module to re-export the output
4. `.tfvars`, `-var` and `TF_VAR_` work for **root module variables only**
5. An input variable with no `default` is **required**. With a `default`, it is **optional**
6. **Providers are the exception**: child modules inherit them from the root

### Interview POV
> **Q: Can a child module use a variable defined in the root?**
> No. Each module has its own scope. The root must pass the value explicitly as an argument in the `module` block, and the child must declare a matching `variable`. Values come back only through `output` blocks.

---

## 5. Using Modules from the Terraform Registry

The **Terraform Registry** ([registry.terraform.io](https://registry.terraform.io)) is HashiCorp's public catalogue of providers and **ready-made modules** that anyone can use.

### Registry source format
| Registry | `source` format | Example |
|---|---|---|
| **Public** Registry | `<NAMESPACE>/<NAME>/<PROVIDER>` | `Azure/vnet/azurerm` |
| **Private** Registry (HCP Terraform / Enterprise) | `<HOSTNAME>/<ORGANIZATION>/<NAME>/<PROVIDER>` | `app.terraform.io/myorg/vnet/azurerm` |

- **NAMESPACE**: the publisher (user or organization), e.g. `Azure`, `hashicorp`, `terraform-aws-modules`
- **NAME**: what the module builds, e.g. `vnet`, `aks`
- **PROVIDER**: the main provider it uses, e.g. `azurerm`, `aws`

### Steps to use a Registry module
1. **Find it** on the Registry: search, filter by provider, and prefer modules with a **Partner / Verified** badge or official publishers
2. **Read its docs tab.** The Registry auto-generates **Inputs** (required and optional), **Outputs**, **Dependencies** and **Resources** from the module code
3. **Copy the "Provision Instructions"** snippet (`source` + `version`) into your code
4. **Pass the required inputs** and pin a `version`
5. Run **`terraform init`** to download it into `.terraform/modules/`, then `plan` and `apply`

```hcl
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-network-dev"
  location = "eastus"
}

module "vnet" {
  source  = "Azure/vnet/azurerm"     # public Registry module
  version = "~> 4.1"                 # always pin

  # required inputs (from the module's "Inputs" tab)
  resource_group_name = azurerm_resource_group.rg.name
  vnet_location       = azurerm_resource_group.rg.location

  # optional inputs (they have defaults; override if needed)
  vnet_name       = "vnet-app-dev"
  address_space   = ["10.0.0.0/16"]
  subnet_prefixes = ["10.0.1.0/24", "10.0.2.0/24"]
  subnet_names    = ["snet-web", "snet-app"]
  use_for_each    = true
}

output "vnet_id" {
  value = module.vnet.vnet_id         # names listed on the module's "Outputs" tab
}
```

```bash
terraform init
# Initializing modules...
# Downloading registry.terraform.io/Azure/vnet/azurerm 4.x.x for vnet...
```

> Input/output names differ between modules and between versions. Always check the Registry docs for the **exact version** you pin.

### Using a Private Registry module
```hcl
module "vnet" {
  source  = "app.terraform.io/myorg/vnet/azurerm"
  version = "1.0.0"
}
```
```bash
terraform login        # stores an API token so init can download from the private registry
terraform init
```

### Publishing a module to the Public Registry (requirements)
| Requirement | Detail |
|---|---|
| **Hosted on GitHub** | A **public** GitHub repository |
| **Repo naming** | `terraform-<PROVIDER>-<NAME>`, e.g. `terraform-azurerm-vnet` |
| **Description** | The repo description is used as the module's short description |
| **Standard module structure** | `main.tf`, `variables.tf`, `outputs.tf`, `README.md` in the repo root (plus optional `modules/`, `examples/`) |
| **Version tags** | Git release tags in SemVer, e.g. `v1.0.0` or `1.0.0`. **Each tag becomes a version** on the Registry |

### Public vs Private Registry
| | Public Registry | Private Registry |
|---|---|---|
| Who can use it | Anyone | Only members of your HCP Terraform / Enterprise organization |
| Source format | 3 parts | 4 parts (includes hostname) |
| Authentication | Not needed | `terraform login` / API token |
| Use case | Community and vendor modules | Internal, company-approved modules |

---

## Important Points (Exam)
1. Public Registry source: **`<NAMESPACE>/<NAME>/<PROVIDER>`**. Private: **`<HOSTNAME>/<ORG>/<NAME>/<PROVIDER>`**
2. The **`version` argument works only with Registry modules** (public or private)
3. Publishing repo name **must** be `terraform-<PROVIDER>-<NAME>` on a **public GitHub** repo
4. Registry versions come from **Git tags** in SemVer format
5. Run **`terraform init`** to download Registry modules. They are stored in **`.terraform/modules/`**
6. **Partner/Verified** modules are reviewed by HashiCorp and maintained by trusted partners. They are a safer choice
7. A Registry module's **required inputs** are the variables with no default. You must pass them in the `module` block
8. Private registry needs **`terraform login`** (or a token) before `terraform init`

### Interview POV
> **Q: Public Registry module or write your own?**
> Use a well-maintained public module (Verified, or Azure Verified Modules) for standard building blocks to save time. Many companies wrap or fork them into a **private registry** to enforce standards like naming, tags and security settings, and pin versions.

---

## 6. Writing Your Own Module & Using It

### Standard module structure
```
terraform-azurerm-storage/        # repo name if publishing: terraform-<PROVIDER>-<NAME>
├── main.tf          # resources
├── variables.tf     # inputs (with type, description, validation)
├── outputs.tf       # return values
├── versions.tf      # terraform + required_providers constraints (NO provider block)
├── README.md        # usage docs
├── examples/        # sample root modules that call this module
│   └── basic/main.tf
└── modules/         # optional nested sub-modules
```

### Step 1: Write the module
```hcl
# versions.tf
terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"      # minimum version in modules; the root decides the exact one
    }
  }
}
```

```hcl
# variables.tf
variable "name" {
  description = "Storage account name (3-24 lowercase letters/numbers)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "Name must be 3-24 lowercase letters or numbers."
  }
}

variable "resource_group_name" {
  description = "Existing resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "replication_type" {
  type    = string
  default = "LRS"
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

```hcl
# main.tf
locals {
  common_tags = merge({ managed_by = "terraform" }, var.tags)   # private to this module
}

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  min_tls_version          = "TLS1_2"    # enforced standard; callers can't change it
  tags                     = local.common_tags
}
```

```hcl
# outputs.tf
output "id" {
  description = "Storage account ID"
  value       = azurerm_storage_account.this.id
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.this.primary_blob_endpoint
}

output "primary_access_key" {
  value     = azurerm_storage_account.this.primary_access_key
  sensitive = true          # hidden in CLI output
}
```

### Step 2: Use the module (3 ways to source it)
```hcl
# a) Local path: same repo, no versioning
module "storage" {
  source = "./modules/storage"
  ...
}

# b) Git: shared across repos, version with ?ref=
module "storage" {
  source = "git::https://github.com/myorg/terraform-azurerm-storage.git?ref=v1.0.0"
  ...
}

# c) Registry (public or private): version with the version argument
module "storage" {
  source  = "app.terraform.io/myorg/storage/azurerm"
  version = "~> 1.0"
  ...
}
```

### Step 3: Call it multiple times with `for_each`
```hcl
# root main.tf
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-app"
  location = "eastus"
}

locals {
  envs = {
    dev  = "LRS"
    prod = "GRS"
  }
}

module "storage" {
  source   = "./modules/storage"
  for_each = local.envs                      # count / for_each / depends_on work on modules (TF 0.13+)

  name                = "stapp${each.key}001"
  resource_group_name = azurerm_resource_group.rg.name
  replication_type    = each.value
  tags                = { env = each.key }
}

output "storage_ids" {
  value = { for k, m in module.storage : k => m.id }   # module.storage["dev"].id
}
```
State addresses: `module.storage["dev"].azurerm_storage_account.this`, `module.storage["prod"].azurerm_storage_account.this`

### Step 4: Init and apply
```bash
terraform init      # required whenever a module block is added or its source changes
terraform validate
terraform plan
terraform apply
```

### Best practices for writing modules
| Do | Don't |
|---|---|
| Give every variable and output a `type` and `description` | Put a `provider` block inside a reusable module |
| Use `validation` blocks to catch bad input early | Hardcode environment values (names, regions, SKUs) |
| Set sensible `default`s, and make only essentials required | Expose every possible argument (keep the interface small) |
| Use `versions.tf` with **minimum** provider versions (`>=`) | Pin exact provider versions in a child module |
| Mark secrets as `sensitive = true` | Build "wrapper" modules around a single resource with no added value |
| Name the single main resource `this` | Nest modules too deeply (keep the tree shallow) |
| Tag releases with SemVer and keep a README with examples | Change inputs or outputs without bumping the MAJOR version |

---

## Important Points (Exam)
1. A module = **directory** of `.tf` files. The standard files are `main.tf`, `variables.tf`, `outputs.tf` and `README.md`
2. `count`, `for_each` and `depends_on` are supported on `module` blocks (TF **0.13+**)
3. With `for_each`, access outputs as `module.<NAME>["<KEY>"].<OUTPUT>`. With `count`, use `module.<NAME>[0].<OUTPUT>`
4. Child modules declare `required_providers` but **no `provider` configuration**. Providers come from the root
5. `sensitive = true` on an output hides it in CLI output, but it is still stored in **plain text in state**
6. Source types: **local** (no version), **Git** (`?ref=`), **Registry** (`version`). Others include S3, GCS, HTTP and Bitbucket
7. Any change to a module's `source` or a new module block requires **`terraform init`**

---

## Module Summary (Cheat Sheet)
| Topic | Key fact |
|---|---|
| Root module | Where you run Terraform. Every configuration has one |
| Child module | Called with a `module` block. `source` is required |
| Pass data in | Module arguments → child `variable`s |
| Get data out | Child `output` → `module.<NAME>.<OUTPUT>` |
| Scope | Fully isolated (except providers, which are inherited) |
| Versioning | Registry → `version`. Git → `?ref=`. Local → none |
| Upgrade | `terraform init -upgrade` (stays within constraints) |
| Public Registry source | `<NAMESPACE>/<NAME>/<PROVIDER>` |
| Private Registry source | `<HOST>/<ORG>/<NAME>/<PROVIDER>` |
| Publish naming | GitHub repo `terraform-<PROVIDER>-<NAME>` + SemVer tags |
| Downloaded to | `.terraform/modules/` |

### Interview POV
> **Q: How do you design a reusable module?**
> Keep it focused on one purpose with a small, typed and validated input interface. Enforce org standards inside (TLS, tags, naming), expose only useful outputs and declare minimum provider versions without a provider block. Document it with a README and examples, release with SemVer tags, and consume it via Git `?ref=` or a private registry with pinned versions. Use `for_each` on the module block to stamp out multiple environments or instances.
