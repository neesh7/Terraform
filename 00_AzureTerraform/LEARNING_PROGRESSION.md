# Terraform Core Concepts - Structured Learning Flow

> A systematic progression through Terraform fundamentals, from basics to advanced infrastructure-as-code patterns.

---

## 🎯 Level 0: Foundation Principles (Conceptual)

These principles underpin everything you build in Terraform:

### 0.1 What is Terraform?
- **Definition**: Infrastructure-as-Code (IaC) tool for provisioning cloud infrastructure
- **Purpose**: Define desired state in config files; let Terraform manage the rest
- **Key insight**: You declare WHAT you want, not HOW to build it (declarative)

### 0.2 What is a Provider?

**In 1 line**: A provider is a plugin that translates Terraform code into API calls to your cloud platform (AWS, Azure, GCP, etc.).

**More detail**: Each provider has resources (e.g., `azurerm_virtual_machine`, `aws_instance`) that map to real cloud objects. Terraform downloads the provider plugin during `terraform init` and uses it to authenticate and communicate with your cloud account.

```hcl
provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# Now you can use azurerm_* resources
resource "azurerm_resource_group" "main" {
  name     = "my-rg"
  location = "eastus"
}
```

### 0.3 Core Principles

| Principle | Meaning | Example |
|-----------|---------|---------|
| **Idempotence** | Multiple `terraform apply` runs achieve the same state—no duplicates | Running apply 5 times = running once |
| **Immutability** | Changes to config → infrastructure is recreated, not modified | Update a property → full resource rebuild |
| **Encapsulation** | Hide complexity inside modules; expose only inputs/outputs | Module = sealed container with clean interface |
| **Cohesion** | Group closely related resources in one module (single responsibility) | All VPC resources in one module |
| **Declarative** | Define desired state, not implementation steps | `resource "aws_instance"...` not `ssh && apt-get install` |
| **DRY (Don't Repeat Yourself)** | Reuse code via modules; don't copy-paste | Write once, call many times |
| **Cloud Agnostic** | Same patterns work across AWS, Azure, GCP, etc. | Provider is the only thing that changes |

---

## 🔧 Level 1: Terraform Workflow & Syntax (01-Lab)

**Where to practice**: `01-Lab/`  
**What you learn**: How Terraform works, basic syntax, and resource creation

### 1.1 Core Terraform Workflow

```
① terraform init    → Download providers (plugin binaries)
② terraform plan    → Show what WILL change (dry-run)
③ terraform apply   → Execute the changes
④ terraform destroy → Remove all resources
```

### 1.1.1 Workflow Stage Breakdown

| Stage | Command | What happens | Output |
|-------|---------|--------------|--------|
| **Initialize** | `terraform init` | Downloads provider plugins (.terraform/), initializes backend | Plugin binaries cached locally |
| **Validate** | `terraform validate` | Checks HCL syntax for errors (no cloud calls) | ✅ or ❌ syntax errors |
| **Plan** | `terraform plan` | Compares desired state (code) vs current state (cloud) via API calls; shows exact changes | Plan file showing +/~/- resources |
| **Apply** | `terraform apply` | Executes changes from plan; updates terraform.tfstate with new resource IDs | Infrastructure changed, state updated |
| **Destroy** | `terraform destroy` | Removes all resources managed by Terraform | All Terraform-managed resources deleted |

**Key insight**: Plan is a **dry-run**—it's safe to run anytime. It calls your cloud API to fetch current state but doesn't make changes.

### 1.1.2 How terraform Detects Drift (Configuration Changes)

**The Process**:
1. Terraform doesn't watch continuously (unlike Kubernetes controllers)
2. Drift detection happens **only when you run `terraform plan` or `terraform apply`**
3. Terraform fetches current state from cloud via API and compares it to your code
4. Any difference is reported as "drift" in the plan

**In 1 line**: Terraform is **pull-based** (checks on demand), not **push-based** (watches continuously).

### 1.1.3 Is This a Problem in Production? How to Handle It?

**The Challenge**:
```
Time 0: terraform apply → Cloud state = Terraform state ✅
Time 1-4: Someone manually changes infrastructure in cloud console (or bug)
Time 5: Your code is now out of sync with cloud, but Terraform doesn't know yet
Time 6: You run terraform plan → Detects drift → Plan shows unexpected changes
```

**Solutions for Production**:

**Option 1: Policy as Code (Prevent Manual Changes)**
- Lock cloud console access—only allow changes via Terraform
- Use Azure Policy/AWS SCPs to prevent manual resource creation
- Gate all changes through CI/CD pipeline (only terraform apply allowed)

**Option 2: Monitoring & Alerts (Detect Drift Early)**
```bash
# Run terraform plan on a schedule (e.g., every 6 hours)
# If it detects drift → alert team immediately
# Manual change detected → team must either:
#   (a) Update Terraform code to match, or
#   (b) Undo the manual change
```

Example CI/CD schedule:
```yaml
# .github/workflows/drift-detection.yml
schedule:
  - cron: '0 */6 * * *'  # Every 6 hours
run: terraform plan
if: plan shows changes → send Slack alert
```

**Option 3: State Locking (Prevent Concurrent Changes)**
```hcl
# Using Azure remote backend with state locking
terraform {
  backend "azurerm" {
    resource_group_name  = "my-rg"
    storage_account_name = "mystorageaccount"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
  }
}
```
- Remote state with locking prevents multiple `terraform apply` from running simultaneously
- Prevents race conditions and concurrent modifications

**Best Practice for Production**:
1. **Enforce remote backend with locking**
2. **Run drift detection every 6 hours** via CI/CD
3. **Alert on any drift** (Slack, PagerDuty, etc.)
4. **Document policy**: "All changes must go through Terraform; manual changes are forbidden"
5. **Regular audits**: Check terraform plan output before any apply

### 1.2 HCL Syntax Basics

```hcl
resource "provider_type" "local_name" {
  argument = value
}
```

**Example**: [01-Lab/main.tf](01-Lab/main.tf)
```hcl
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}
```

### 1.2.1 Terraform Directory Structure & Files

**Single-Environment Project** (simple):
```
project/
├── main.tf              # Resource definitions
├── variables.tf         # Input variable declarations
├── output.tf            # Output values
├── versions.tf          # Provider versions
├── terraform.tfvars     # Variable values (dev environment)
├── .gitignore           # Ignore state files
├── .terraform/          # Provider plugins (auto-created)
└── terraform.tfstate    # Current state (never commit!)
```

**Multi-Environment Project** (production):
```
project/
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── output.tf
│   └── storage/
│       ├── main.tf
│       ├── variables.tf
│       └── output.tf
│
├── environments/
│   ├── dev/
│   │   ├── main.tf              # Root module for dev
│   │   ├── variables.tf
│   │   ├── output.tf
│   │   ├── versions.tf
│   │   ├── terraform.tfvars     # dev values
│   │   └── dev.tfstate          # state for dev
│   │
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── output.tf
│   │   ├── versions.tf
│   │   ├── terraform.tfvars
│   │   └── staging.tfstate
│   │
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── output.tf
│       ├── versions.tf
│       ├── terraform.tfvars
│       └── prod.tfstate
│
├── .gitignore
├── README.md
└── .terraformignore
```

### 1.2.2 File Purposes & Content

| File | Purpose | Example |
|------|---------|---------|
| `main.tf` | Resource definitions and module calls | `resource "azurerm_resource_group"`, `module "networking"` |
| `variables.tf` | **Declare** input variables (what, type, description) | `variable "environment" { type = string }` |
| `output.tf` | **Declare** output values (what to display after apply) | `output "app_url" { value = azurerm_app_service.main.url }` |
| `versions.tf` | Provider and Terraform version constraints | `required_providers { azurerm = { version = "~> 3.0" } }` |
| `terraform.tfvars` | **Assign** values to variables (dev environment) | `environment = "dev"` |
| `*.auto.tfvars` | Auto-loaded variable files (alphabetically sorted) | `prod.auto.tfvars`, `secrets.auto.tfvars` |
| `terraform.tfstate` | Current infrastructure state (JSON, DO NOT commit!) | Created automatically after `terraform apply` |
| `.gitignore` | Tell Git to ignore Terraform files | `terraform.tfstate*`, `.terraform/`, `*.tfvars` |
| `backend.tf` | Remote state configuration | `backend "azurerm" { ... }` |

### 1.4 Key Concepts: Referencing Resource Output

In HCL, access a resource's output with dot notation:
```hcl
resource "random_string" "suffix" {
  length = 6
}

output "suffix_value" {
  value = random_string.suffix.result  # → outputs the generated string
}
```

### 1.5 String Interpolation

Insert dynamic values into strings using `${}`:
```hcl
locals {
  # String interpolation
  environment_prefix = "${var.application_name}-${var.environment_name}-${random_string.suffix.result}"
}
# Result: "myapp-dev-abc123"
```

**Where to practice**: [01-Lab/main.tf](01-Lab/main.tf), [01-Lab/variables.tf](01-Lab/variables.tf)

---

## 📥 Level 2: Input Variables & State Management (02-Lab-InputVariables)

**Where to practice**: `02-Lab-InputVariables/`  
**What you learn**: How to parameterize Terraform code and manage variable values

### 2.1 Declaring vs. Assigning Variables

**Declaration** (`variables.tf`) - what the variable is:
```hcl
variable "environment_name" {
  type        = string
  description = "Environment (dev, staging, prod)"
  default     = "dev"
}
```

**Assignment** (multiple options, in precedence order):
1. `default` in variable block
2. Environment variable `TF_VAR_<name>` (useful for secrets in CI)
3. `terraform.tfvars` (auto-loaded, unversioned)
4. `*.auto.tfvars` (auto-loaded, alphabetically sorted)
5. `-var-file prod.tfvars` (CLI flag for env-specific files)
6. `-var "name=value"` (CLI flag, highest precedence)
7. Interactive prompt (if no value found + no default)

### 2.2 Input Variable Types

```hcl
variable "string_var" {
  type = string
}

variable "number_var" {
  type = number
}

variable "bool_var" {
  type = bool
}

variable "list_var" {
  type = list(string)  # ["item1", "item2"]
}

variable "map_var" {
  type = map(string)   # { key = "value", key2 = "value2" }
}
```

### 2.3 Input Variable Validation

```hcl
variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 100
    error_message = "Instance count must be between 1 and 100."
  }
}
```

### 2.4 Sensitive Variables

Hide values in logs/output:
```hcl
variable "database_password" {
  type      = string
  sensitive = true  # Won't appear in terraform plan/apply output
}

output "app_url" {
  value     = aws_instance.web.public_ip
  sensitive = true
}
```

### 2.5 Using Variables in Code

```hcl
resource "aws_instance" "web" {
  instance_type = var.instance_type
  # Use var.<name> to reference
}

locals {
  environment_prefix = "${var.environment_name}-${random_string.suffix.result}"
}
```

### 2.6 Commands Involving Variables

```bash
# Use default values (from variable defaults or .tfvars)
terraform plan

# Override a specific variable
terraform plan -var "environment_name=prod"

# Use a specific .tfvars file (prod.tfvars won't auto-load without -var-file)
terraform plan -var-file=prod.tfvars

# Set via environment variable (best for secrets)
export TF_VAR_database_password="secret123"
terraform apply
```

**PowerShell equivalent**:
```powershell
$env:TF_VAR_database_password = "secret123"
terraform apply
```

**Where to practice**: [02-Lab-InputVariables/](02-Lab-InputVariables/)

---

## 🔁 Level 3: Loops & Conditionals (02-Lab-InputVariables Advanced)

**What you learn**: How to dynamically create multiple resources

### 3.1 count - Iterate Over Lists

Use when you have a **list** and want to create N copies of a resource:

```hcl
variable "regions" {
  type = list(string)
  default = ["us-east-1", "us-west-1", "eu-west-1"]
}

resource "random_string" "list" {
  count  = length(var.regions)
  length = 6
}

output "all_strings" {
  value = random_string.list[*].result  # → ["abc123", "def456", "ghi789"]
}
```

**Reference individual items**: `random_string.list[0].result`, `random_string.list[1].result`, etc.

### 3.2 for_each - Iterate Over Maps

Use when you have a **map** and want to create a resource per key-value pair:

```hcl
variable "regions_instance_count" {
  type = map(number)
  default = {
    us-east  = 3
    eu-west  = 5
    ap-south = 2
  }
}

resource "random_string" "map" {
  for_each = var.regions_instance_count
  length   = 6
}

output "instances_per_region" {
  value = random_string.map["us-east"].result  # → specific instance
  # or
  value = { for k, v in random_string.map : k => v.result }
}
```

**Key insight**: 
- `count` → zero-indexed array (like Python lists)
- `for_each` → map keyed by your custom keys

### 3.3 Conditionals (Ternary Operator)

Create a resource only if a condition is true:

```hcl
variable "enabled" {
  type    = bool
  default = true
}

resource "random_string" "if_check" {
  count  = var.enabled ? 1 : 0  # Syntax: condition ? if_true : if_false
  length = 6
}

# If enabled=true → count=1 (resource created)
# If enabled=false → count=0 (resource NOT created)
```

**Use in locals**:
```hcl
locals {
  environment_tier = var.is_production ? "prod" : "dev"
}
```

### 3.4 Combining count + Locals

```hcl
locals {
  min_nodes = 5
  max_nodes = 9
}

# Create 5-9 instances based on a variable
resource "aws_instance" "cluster" {
  count         = var.enable_autoscaling ? local.max_nodes : local.min_nodes
  instance_type = "t2.micro"
}
```

### 3.5 Deep Dive: `count` vs `for_each` — Which to Use Where

**The core idea**: Both are **meta-arguments** that let one `resource`/`module` block create *multiple instances*. The difference is how Terraform **addresses** those instances in state.

| | `count` | `for_each` |
|---|---|---|
| Takes | a number (often `length(list)`) | a **map** or a **set of strings** |
| Instance address | `res.name[0]`, `[1]`, `[2]` … (integer index) | `res.name["key"]` (string key) |
| Iterator object | `count.index` | `each.key`, `each.value` |
| Identity based on | **position** in the list | **the key** |

That last row is the whole ballgame.

#### 3.5.1 `count` + `list`

```hcl
variable "users" {
  default = ["alice", "bob", "carol"]
}

resource "azurerm_resource_group" "this" {
  count    = length(var.users)
  name     = "rg-${var.users[count.index]}"
  location = "eastus"
}
```

Creates `...this[0]` (alice), `...this[1]` (bob), `...this[2]` (carol).

**The problem**: state is keyed by **index**, not value. If you remove `"alice"`:

```hcl
default = ["bob", "carol"]
```

- `[0]` alice → bob  → **Terraform replaces** instance 0
- `[1]` bob → carol → **replaces** instance 1
- `[2]` carol → gone → **destroys** instance 2

One deletion from the front/middle cascades destroy/recreate onto everything after it. Harmless for stateless things; a disaster for databases, disks, or anything stateful.

➡️ `count` is safe with a list only when the list is **append-only** (you only ever add to the end).

#### 3.5.2 `for_each` + `map`

```hcl
variable "users" {
  default = {
    alice = { role = "admin",     dept = "eng" }
    bob   = { role = "developer", dept = "eng" }
    carol = { role = "readonly",  dept = "fin" }
  }
}

resource "azurerm_resource_group" "this" {
  for_each = var.users
  name     = "rg-${each.key}"
  location = "eastus"
  tags = {
    role = each.value.role
    dept = each.value.dept
  }
}
```

Creates `...this["alice"]`, `...this["bob"]`, `...this["carol"]`.

Remove `bob` from the map → Terraform destroys **only** `...this["bob"]`. Alice and carol are untouched because their keys didn't change. **This is why `for_each` is the modern default.**

#### 3.5.3 `for_each` + set of strings

If you only have names (no per-item config), convert the list to a set:

```hcl
variable "users" {
  default = ["alice", "bob", "carol"]
}

resource "azurerm_resource_group" "this" {
  for_each = toset(var.users)
  name     = "rg-${each.value}"   # with a set, each.key == each.value
  location = "eastus"
}
```

Instances are keyed `["alice"]`, `["bob"]`, `["carol"]` — value-stable, so removals are surgical.

#### 3.5.4 Which to use where

**Default to `for_each`.** Reach for `count` only in these cases:

| Situation | Use |
|---|---|
| N identical things where identity doesn't matter | `count` |
| Conditional single resource: create it or don't | `count = var.enabled ? 1 : 0` |
| Each instance needs its own distinct config / name | `for_each` (map) |
| Instances must survive siblings being added/removed | `for_each` |
| Source data is already a map | `for_each` |
| Source data is a list of unique strings | `for_each` + `toset()` |
| Source data is a list of **objects** | `for_each` over `{ for o in list : o.name => o }` |

#### 3.5.5 The conditional idiom (count's best use)

```hcl
resource "azurerm_public_ip" "bastion" {
  count               = var.create_bastion ? 1 : 0
  name                = "pip-bastion"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
}

# reference safely:
# one(azurerm_public_ip.bastion[*].id)   → the id, or null if none
```

Newer style prefers `for_each` even here:

```hcl
resource "azurerm_public_ip" "bastion" {
  for_each            = var.create_bastion ? { enabled = true } : {}
  name                = "pip-bastion"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
}
```

#### 3.5.6 Converting a list of objects to a map for `for_each`

`for_each` needs unique keys, so key on a stable unique field:

```hcl
variable "rules" {
  default = [
    { name = "http",  port = 80 },
    { name = "https", port = 443 },
  ]
}

resource "azurerm_network_security_rule" "this" {
  for_each                = { for r in var.rules : r.name => r }
  name                    = each.key
  destination_port_range  = each.value.port
  # ...
}
```

#### 3.5.7 Referencing all instances

```hcl
# count → splat expression, returns a list
azurerm_resource_group.this[*].id

# for_each → values() / keys(), or a for expression
values(azurerm_resource_group.this)[*].id
[for g in azurerm_resource_group.this : g.id]
keys(azurerm_resource_group.this)          # the set of keys
```

#### 3.5.8 Rule of thumb

- **`count`** = "give me N of these" — position-based; good for conditionals and truly interchangeable instances.
- **`for_each`** = "give me one per entry in this map/set" — key-based; stable under change; needed whenever instances have identity.
- If unsure, use `for_each`. The only cost is producing a map/set instead of a list.

**Where to practice**: [02-Lab-InputVariables/main.tf](02-Lab-InputVariables/main.tf)

---

## 📦 Level 4: Terraform Modules (03-Lab-Modules)

**Where to practice**: `03-Lab-Modules/`  
**What you learn**: How to package reusable infrastructure code

### 4.1 What is a Module?

A **module** is a folder containing Terraform code (`.tf` files) that can be:
- Reused across projects
- Versioned independently
- Called from other Terraform code
- Exposed via clean input/output interface

Every Terraform config is itself a module (root module).

### 4.2 Module Structure

```
my-module/
├── main.tf       # Resource definitions
├── variables.tf  # Input variable declarations
├── output.tf     # Output definitions (the module's "return value")
└── README.md     # Documentation
```

### 4.2.5 What is a Terraform Module? (Deep Dive)

**In 1 line**: A module is a reusable folder of Terraform code that encapsulates infrastructure.

**Why modules matter**:
- **Reusability**: Write once, use in multiple places
- **Abstraction**: Hide complexity from users
- **Versioning**: Update infrastructure code independently
- **Consistency**: Enforce naming conventions and best practices

**Real-world example**:

Instead of writing VPC, subnets, security groups, route tables in every project:
```hcl
# ❌ Without modules (lots of boilerplate)
resource "aws_vpc" "main" { ... }
resource "aws_subnet" "private" { ... }
resource "aws_security_group" "app" { ... }
resource "aws_route_table" "main" { ... }
# ... repeat 50 more lines

# ✅ With modules (clean interface)
module "vpc" {
  source = "./modules/vpc"
  cidr   = "10.0.0.0/16"
  name   = "prod-vpc"
}
```

**Module Structure**: A module is just a folder with `.tf` files:
```
modules/vpc/
├── main.tf              # Resource definitions
├── variables.tf         # Input variable declarations
├── output.tf            # Output definitions (what callers receive)
├── README.md            # Documentation
└── versions.tf          # Provider versions
```

**Key concept**: Module users only interact with `variables.tf` (inputs) and `output.tf` (outputs). The implementation in `main.tf` is hidden.

### 4.3 Calling a Module

**Local module** (in your repo):
```hcl
module "my_vpc" {
  source = "./modules/vpc"  # Path to module folder
  
  # Pass inputs
  cidr_block = "10.0.0.0/16"
  name       = "prod-vpc"
}

# Reference module outputs
output "vpc_id" {
  value = module.my_vpc.vpc_id
}
```

**Remote module** (from Terraform Registry or Git):
```hcl
module "random_string" {
  source  = "hashicorp/module/random"
  version = "1.0.0"
}
```

### 4.4 Module Inputs & Outputs

**Module's `variables.tf`**:
```hcl
variable "cidr_block" {
  type = string
}

variable "name" {
  type = string
}
```

**Module's `output.tf`**:
```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = aws_subnet.private[*].id
}
```

**Root config calling the module**:
```hcl
module "my_vpc" {
  source     = "./modules/vpc"
  cidr_block = "10.0.0.0/16"
  name       = "prod-vpc"
}

# Access outputs
output "vpc_id" {
  value = module.my_vpc.vpc_id  # dot notation to access outputs
}
```

### 4.5 Meta-Arguments for Modules

Apply `count`/`for_each` to modules themselves:

**Using count on module**:
```hcl
variable "environments" {
  type = list(string)
  default = ["dev", "staging", "prod"]
}

module "env" {
  for_each = toset(var.environments)
  source   = "./modules/env"
  
  env_name = each.value
}

# Access: module.env["dev"].vpc_id, module.env["prod"].vpc_id
```

**Where to practice**: [03-Lab-Modules/](03-Lab-Modules/)

---

## 🌍 Level 4.5: Managing Multiple Environments (dev/staging/prod)

**Critical for real-world Terraform usage**

### 4.5.1 The Problem: One Code, Multiple Environments

You want to deploy the same infrastructure to **dev**, **staging**, and **prod**, but with different configurations:

```
Dev:     2 instances, 1GB RAM, auto-scaling disabled
Staging: 4 instances, 2GB RAM, auto-scaling enabled
Prod:    8 instances, 4GB RAM, auto-scaling enabled, backups enabled
```

### 4.5.2 Solution 1: Separate .tfvars Files (Recommended for Production)

**Directory structure**:
```
environments/
├── dev/
│   ├── main.tf
│   ├── variables.tf
│   ├── output.tf
│   ├── versions.tf
│   └── terraform.tfvars      # dev-specific values
├── staging/
│   ├── main.tf
│   ├── variables.tf
│   ├── output.tf
│   ├── versions.tf
│   └── terraform.tfvars      # staging-specific values
└── prod/
    ├── main.tf
    ├── variables.tf
    ├── output.tf
    ├── versions.tf
    └── terraform.tfvars      # prod-specific values
```

**Each environment has its own directory** with separate state file.

**Dev terraform.tfvars**:
```hcl
environment          = "dev"
instance_count       = 2
instance_type        = "t2.micro"
enable_autoscaling   = false
backup_enabled       = false
```

**Prod terraform.tfvars**:
```hcl
environment          = "prod"
instance_count       = 8
instance_type        = "t2.large"
enable_autoscaling   = true
backup_enabled       = true
```

**How to deploy**:
```bash
# Deploy to dev
cd environments/dev
terraform init
terraform plan
terraform apply

# Deploy to prod
cd environments/prod
terraform init
terraform plan
terraform apply
```

**Pros**:
- Clear separation (each env has own state file)
- Easy to manage different configurations
- Safe (prod changes don't affect dev)

**Cons**:
- Code duplication (main.tf repeated in each env)
- Must manually cd into each directory

### 4.5.3 Solution 2: Workspaces (Separate States, Same Code)

**Workspaces** allow you to manage multiple environments in the **same directory** with **different state files**:

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# List all workspaces
terraform workspace list
# Output:
# default
# dev
# prod
# * staging
# └── staging (currently selected)

# Switch between workspaces
terraform workspace select dev
terraform workspace select prod

# Current workspace in code
locals {
  env = terraform.workspace  # "dev", "prod", etc.
}
```

**Same main.tf for all environments**:
```hcl
locals {
  env = terraform.workspace
  
  instance_counts = {
    dev     = 2
    staging = 4
    prod    = 8
  }
  
  instance_types = {
    dev     = "t2.micro"
    staging = "t2.small"
    prod    = "t2.large"
  }
}

resource "aws_instance" "main" {
  count         = local.instance_counts[local.env]
  instance_type = local.instance_types[local.env]
}
```

**Single terraform.tfvars** (or workspace-specific):
```hcl
environment = terraform.workspace  # Automatically "dev", "prod", etc.
```

**How to deploy**:
```bash
# Deploy to dev
terraform workspace select dev
terraform apply

# Deploy to prod
terraform workspace select prod
terraform apply
```

**Pros**:
- Single code base (no duplication)
- Easy to switch between environments
- Good for small teams

**Cons**:
- All environments in same directory (harder to manage with team)
- Workspaces can be tricky with remote state backends
- Easy to accidentally deploy prod from dev code

### 4.5.4 Solution 3: Hybrid (Best for Teams)

**Combine separate directories + workspaces**:

```
environments/
├── dev/
│   └── (terraform workspace: default, staging, prod)
└── prod/
    └── (terraform workspace: staging, prod)
```

**OR use directories for major splits, workspaces for minor variations**:

```
environments/
├── shared/         # Common modules
├── dev/
│   ├── main.tf     # Uses local.env
│   └── terraform.tfvars
└── prod/
    ├── main.tf
    └── terraform.tfvars
```

### 4.5.5 Practical Command Examples

**Multi-environment deployment**:
```bash
# Deploy dev
cd environments/dev
terraform init
terraform plan -out=dev.tfplan
terraform apply dev.tfplan

# Deploy prod (different directory)
cd ../prod
terraform init
terraform plan -out=prod.tfplan
terraform apply prod.tfplan
```

**With -var-file flag** (from root project directory):
```bash
# Using separate .tfvars files without changing directories
terraform init -backend-config=environments/dev/backend.tf
terraform plan -var-file=environments/dev/terraform.tfvars

# Deploy prod
terraform plan -var-file=environments/prod/terraform.tfvars -out=prod.tfplan
terraform apply prod.tfplan
```

**Override variables from command line**:
```bash
# Mix file + CLI override
terraform apply \
  -var-file=environments/prod/terraform.tfvars \
  -var="instance_count=16" \
  -var="enable_debug=true"
```

### 4.5.6 Environment Management Best Practices

| Pattern | When to Use | Example |
|---------|------------|---------|
| **Separate directories** | Different teams, different approval workflows | Org 1 prod (strict access), Org 2 prod (looser access) |
| **Workspaces** | Same code, small config variations | Dev vs Prod in same project (different VM sizes) |
| **Modules** | Reuse common infrastructure | All envs use same VPC module with env-specific inputs |
| **Remote backends per env** | Strict isolation (recommended) | dev.tfstate in one storage, prod.tfstate in another (separate Azure subscription) |

**Production Recommendation**:
```
1. Use separate directories (environments/dev, environments/prod)
2. Each directory has its own state file
3. Use remote backends for all
4. Use -var-file for env-specific values
5. Implement approvals in CI/CD (prod requires 2 approvals, dev auto-approves)
```

---

## ☁️ Level 5: Terraform State & Backends (05-Lab-RemoteState-backend)

**Where to practice**: `05-Lab-RemoteState-backend/`  
**What you learn**: How Terraform tracks infrastructure and stores state

### 5.1 What is State?

**State file** (`terraform.tfstate`) is a JSON file that stores:
- Current state of infrastructure (what actually exists in cloud)
- Mapping between Terraform resource names and cloud resource IDs
- Variable values and outputs

**Critical**: State = single source of truth. Terraform compares desired state (your code) vs. current state (tfstate) to determine what to change.

### 5.2 State Locations

**Local state** (default):
```
terraform.tfstate       # Current state
terraform.tfstate.backup  # Previous state backup
```

**Remote state** (recommended for teams):
```hcl
terraform {
  backend "azurerm" {  # Azure backend
    resource_group_name  = "my-rg"
    storage_account_name = "mystorageaccount"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
  }
}
```

### 5.3 Why Remote State?

| Local | Remote |
|-------|--------|
| Easy to start | Safe for teams |
| File-based, unversioned | Centralized, versioned |
| No locking (race conditions) | Built-in locking |
| Must commit to git (security risk) | Stored in cloud (encrypted) |
| Single developer only | Multiple team members |

### 5.4 Terraform Workspaces

Separate state files for different environments (dev/staging/prod) in same code:

```bash
terraform workspace list
terraform workspace new prod
terraform workspace select prod
terraform workspace delete prod
terraform workspace show
```

**Use case**: 
```hcl
locals {
  environment = terraform.workspace  # "default", "dev", "prod", etc.
  
  instance_count = local.environment == "prod" ? 10 : 2
}
```

### 5.5 State File Security

⚠️ **Never commit `terraform.tfstate` to git!**
- Contains values of all variables (including secrets)
- Add to `.gitignore`:
  ```
  terraform.tfstate*
  .terraform/
  *.tfvars  # If contains secrets
  ```

**Safe secret handling**:
```hcl
# Never in code
variable "db_password" {
  type      = string
  sensitive = true
}

# Use environment variables in CI/CD
export TF_VAR_db_password="actual_password"
terraform apply
```

### 5.6 State Commands

```bash
# View current state
terraform state list                 # All resources
terraform state show aws_instance.web  # Specific resource details

# Manually modify state (use with caution)
terraform state rm aws_instance.web  # Remove from state (not from cloud)
terraform state mv old_name new_name  # Rename in state
```

**Where to practice**: [05-Lab-RemoteState-backend/](05-Lab-RemoteState-backend/)

---

## ☁️ Level 6: Azure Infrastructure (04-AzTerraform)

**Where to practice**: `04-AzTerraform/`  
**What you learn**: How to provision real cloud resources in Azure

### 6.1 Azure Provider Setup

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
```

### 6.2 Common Azure Resources

| Resource | Purpose |
|----------|---------|
| `azurerm_resource_group` | Container for all resources |
| `azurerm_storage_account` | Object storage (blobs) |
| `azurerm_virtual_network` | VPC/network |
| `azurerm_subnet` | Subnet within VNet |
| `azurerm_virtual_machine` | Compute instance |
| `azurerm_app_service` | Managed web app platform |
| `azurerm_kubernetes_cluster` | AKS (Kubernetes) |

### 6.3 Naming Conventions

```
{resource_type}-{environment}-{purpose}-{region}
```

**Examples**:
- `rg-prod-webapp-eastus` (Resource Group)
- `st-prod-logs-eastus` (Storage Account)
- `vm-dev-jumpbox-eastus` (Virtual Machine)

**Constraint**: Azure storage account names must be globally unique, lowercase, no hyphens:
- ✅ `stprodlogseastus`
- ❌ `st-prod-logs-eastus` (hyphens not allowed)
- ❌ `ST-PROD-LOGS-EASTUS` (uppercase not allowed)

**Where to practice**: [04-AzTerraform/](04-AzTerraform/)

---

## 🧪 Level 7: Advanced Features & Concepts

### 7.0 Data Sources (Read Existing Infrastructure)

**Problem**: You need to reference infrastructure that already exists (not created by Terraform).

**Solution**: Use `data` blocks to read existing resources:

```hcl
# Read an existing Azure resource group (not managed by Terraform)
data "azurerm_resource_group" "existing" {
  name = "my-existing-rg"
}

# Reference it
resource "azurerm_virtual_machine" "app" {
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location
}

output "resource_group_id" {
  value = data.azurerm_resource_group.existing.id
}
```

**Key difference**:
- `resource` = creates and manages infrastructure
- `data` = reads existing infrastructure (read-only)

**Common data sources**:
- `data "azurerm_resource_group"` - read existing RG
- `data "aws_availability_zones"` - read available zones
- `data "aws_ami"` - read existing machine images

### 7.1 Resource Dependencies (depends_on & Implicit)

**Implicit dependencies** (automatic):
```hcl
resource "azurerm_virtual_network" "main" {
  name                = "my-vnet"
  resource_group_name = azurerm_resource_group.main.name  # ← Implicit dependency
}
```

Terraform automatically detects that VNet depends on RG (because we reference it). Terraform applies RG first, then VNet.

**Explicit dependencies** (manual):
```hcl
resource "aws_instance" "app" {
  ami           = "ami-123"
  depends_on    = [aws_internet_gateway.main]  # ← Explicit dependency
}

# Apply AWS IGW before the instance
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
```

**When to use `depends_on`**: Only when there's a non-obvious dependency that Terraform can't detect automatically (rare).

### 7.2 Lifecycle Rules (Control Resource Behavior)

Control how Terraform creates, updates, and destroys resources:

```hcl
resource "aws_instance" "app" {
  ami = "ami-123"

  lifecycle {
    # Prevent accidental destruction
    prevent_destroy = true
    
    # Create replacement before destroying old one
    create_before_destroy = true
    
    # Ignore changes to tags (won't trigger updates)
    ignore_changes = [tags]
  }
}
```

**Common lifecycle scenarios**:

| Rule | Use Case |
|------|----------|
| `prevent_destroy = true` | Production databases—prevent accidental deletion |
| `create_before_destroy = true` | Blue-green deployments—create new before killing old |
| `ignore_changes = [tags]` | Ignore manual tag changes from cloud console |

### 7.3 Expressions & Functions (Beyond String Interpolation)

**String interpolation** (basic):
```hcl
locals {
  name = "${var.environment}-${var.app_name}"
}
```

**Conditional expression** (ternary):
```hcl
locals {
  instance_type = var.is_prod ? "t2.large" : "t2.micro"
}
```

**Splat operator** (extract values from list):
```hcl
resource "aws_instance" "app" {
  count = 3
  # ...
}

output "all_instance_ids" {
  value = aws_instance.app[*].id  # → ["i-123", "i-456", "i-789"]
}
```

**For expressions** (iterate and transform):
```hcl
variable "instances" {
  type = map(object({ size = string }))
  default = {
    app  = { size = "t2.large" }
    web  = { size = "t2.small" }
  }
}

# Transform into new structure
locals {
  instance_sizes = { for name, config in var.instances : name => config.size }
  # → { app = "t2.large", web = "t2.small" }
}
```

**Built-in functions**:
```hcl
# String functions
length(var.list)                    # → 3
upper("hello")                      # → "HELLO"
join(",", var.list)                 # → "a,b,c"
split(",", "a,b,c")                 # → ["a", "b", "c"]

# Collection functions
keys(var.map)                        # → ["key1", "key2"]
values(var.map)                      # → ["value1", "value2"]
merge(map1, map2)                    # → combined map
flatten([[1,2], [3,4]])             # → [1, 2, 3, 4]

# Type conversion
tostring(123)                        # → "123"
tonumber("123")                      # → 123

# File functions
file("path/to/file")                 # → file contents
templatefile("path.tpl", {var="val"}) # → rendered template
```

### 7.4 Dynamic Blocks (Generate Repeated Blocks)

Instead of writing similar blocks multiple times:
```hcl
# ❌ Repetitive (not DRY)
resource "aws_security_group" "app" {
  name = "app-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ... repeat many more times
}
```

Use `dynamic` to generate blocks:
```hcl
# ✅ DRY
variable "ingress_rules" {
  type = list(object({
    from_port = number
    to_port   = number
  }))
  default = [
    { from_port = 80, to_port = 80 },
    { from_port = 443, to_port = 443 }
  ]
}

resource "aws_security_group" "app" {
  name = "app-sg"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
```

### 7.5 State Locking & Concurrency

**Problem**: Two team members run `terraform apply` simultaneously—both read same state, both make changes → conflict!

**Solution**: Remote backends support **state locking**—only one apply can run at a time.

```hcl
# Azure backend with locking (automatic)
terraform {
  backend "azurerm" {
    resource_group_name  = "tf-state-rg"
    storage_account_name = "tfstate123"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
  }
}

# When you run terraform apply:
# 1. Terraform acquires lock on blob
# 2. Only this apply runs
# 3. After apply → lock released
# 4. Other pending applies proceed
```

**Lock timeout** (rare but useful):
```bash
# If someone forgets apply running (12 hours locked)
terraform force-unlock <lock-id>  # Release stuck lock
```

### 7.6 Importing Existing Infrastructure

**Problem**: You have existing cloud resources not created by Terraform. How do you bring them under Terraform management?

**Solution**: Use `terraform import` to add existing resources to state.

```bash
# Import existing Azure resource group
terraform import azurerm_resource_group.main /subscriptions/{sub-id}/resourceGroups/my-rg

# Import existing VM
terraform import azurerm_virtual_machine.app /subscriptions/{sub-id}/resourceGroups/my-rg/providers/Microsoft.Compute/virtualMachines/my-vm
```

**Steps**:
1. Write resource skeleton in Terraform code (empty resource block)
2. Run `terraform import` to read existing resource and populate state
3. Manually add arguments to resource block (terraform shows what's in state)
4. Run `terraform plan` to verify state matches code

```hcl
# Step 1: Empty resource
resource "azurerm_resource_group" "main" {
}

# Step 2: terraform import azurerm_resource_group.main /subscriptions/...

# Step 3: Add arguments to match imported state
resource "azurerm_resource_group" "main" {
  name     = "my-existing-rg"
  location = "eastus"
  tags = {
    environment = "prod"
  }
}

# Step 4: terraform plan → should show no changes
```

### 7.7 Testing Terraform Code

**Validation** (syntax check):
```bash
terraform validate  # Check HCL syntax
terraform fmt       # Format code
```

**Planning** (dry-run):
```bash
terraform plan -out=plan.out  # Save plan
# Review plan manually
terraform show plan.out       # View saved plan
terraform apply plan.out      # Apply if looks good
```

**Automated testing** (TFLint, TFTest):
```bash
# TFLint - linter for Terraform
tflint                 # Check for issues
tflint --init         # Initialize linter

# Terraform test (Terraform 1.6+)
terraform test        # Run test blocks
```

**Manual testing** (simple environments):
```bash
# Apply to dev
cd environments/dev
terraform apply

# Test manually
curl https://dev-app.example.com

# Destroy after testing
terraform destroy
```

---

## 📚 Level 8: Core Concepts Checklist & Summary

### 7.1 terraform console

Interactive REPL to test expressions, reference outputs, etc.:

```bash
terraform console
> var.application_name
"myapp"

> local.environment_prefix
"myapp-dev-abc123"

> random_string.suffix.result
"abc123"

> exit
```

### 7.2 Terraform Validation

```bash
# Syntax check (before init)
terraform validate

# Format check
terraform fmt --check

# Format and auto-fix
terraform fmt -recursive

# Security scanning
tfsec .
```

### 7.3 Output Values

Define what Terraform should print after `apply`:

```hcl
output "application_name" {
  description = "Name of the deployed application"
  value       = var.application_name
}

output "all_resource_ids" {
  value = {
    for k, v in aws_instance.app : k => v.id
  }
}
```

Access outputs after apply:
```bash
terraform output application_name
terraform output -json  # JSON format
```

---

## 📋 Quick Reference: Command Cheatsheet

```bash
# Initialization
terraform init

# Planning & Validation
terraform validate           # Check syntax
terraform plan              # Show changes
terraform plan -out=tfplan  # Save plan to file

# Applying & Destroying
terraform apply             # Apply changes
terraform apply tfplan      # Apply saved plan
terraform destroy           # Remove all resources

# Inspection
terraform state list        # List all resources
terraform state show <name> # Show resource details
terraform output            # Show outputs
terraform console           # Interactive REPL

# Workspaces
terraform workspace list    # List workspaces
terraform workspace new <name>
terraform workspace select <name>

# Variables & Environment
export TF_VAR_<name>="value"  # Set variable from environment
terraform plan -var="name=value"  # Override variable
terraform plan -var-file=prod.tfvars  # Use .tfvars file
```

---

## 🔨 Practical Examples: Complete Workflows

### Example 1: Deploy to Multiple Environments with -var-file

**Directory structure**:
```
project/
├── main.tf
├── variables.tf
├── output.tf
├── versions.tf
├── environments/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
└── .gitignore
```

**variables.tf**:
```hcl
variable "environment" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "instance_type" {
  type = string
}
```

**dev.tfvars**:
```hcl
environment    = "dev"
instance_count = 2
instance_type  = "t2.micro"
```

**prod.tfvars**:
```hcl
environment    = "prod"
instance_count = 8
instance_type  = "t2.large"
```

**Commands**:
```bash
# Deploy dev
terraform init
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars

# Deploy prod (from same directory!)
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

### Example 2: Using Modules with Multiple Environments

**Directory structure**:
```
project/
├── modules/
│   └── app/
│       ├── main.tf
│       ├── variables.tf
│       └── output.tf
├── environments/
│   ├── dev/
│   │   ├── main.tf  (calls module)
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf  (calls module)
│       └── terraform.tfvars
```

**environments/dev/main.tf**:
```hcl
module "app" {
  source = "../../modules/app"
  
  environment    = "dev"
  instance_count = var.instance_count
  instance_type  = "t2.micro"
}
```

**environments/prod/main.tf**:
```hcl
module "app" {
  source = "../../modules/app"
  
  environment    = "prod"
  instance_count = var.instance_count
  instance_type  = "t2.large"
}
```

**Deploy**:
```bash
# Dev
cd environments/dev
terraform init
terraform apply -var-file=terraform.tfvars

# Prod
cd ../prod
terraform init
terraform apply -var-file=terraform.tfvars
```

### Example 3: Drift Detection Pipeline (CI/CD)

**GitHub Actions workflow** (runs every 6 hours):
```yaml
# .github/workflows/drift-detection.yml
name: Drift Detection

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Terraform Init
        run: terraform init -backend-config=backend.tf
      
      - name: Terraform Plan
        run: terraform plan -var-file=prod.tfvars -out=tfplan
        continue-on-error: true
      
      - name: Check for Drift
        run: |
          if terraform show tfplan | grep -q "No changes"; then
            echo "✅ No drift detected"
          else
            echo "⚠️ Drift detected!"
            echo "Changes:"
            terraform show tfplan
            # Send Slack alert
            curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
              -H 'Content-Type: application/json' \
              -d '{"text":"Terraform drift detected in prod!"}'
          fi
```

### Example 4: State Management with Remote Backend

**backend.tf**:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "tfstate2024"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
  }
}
```

**Initialize remote state**:
```bash
# First time setup
terraform init -backend-config=backend.tf

# Verify remote state is configured
terraform state list  # Should work

# Show state details
terraform state show module.app.azurerm_virtual_machine.main

# Export state locally for backup
terraform state pull > backup.tfstate
```

**State safety**:
```bash
# Never commit state to git!
echo "*.tfstate*" >> .gitignore
echo ".terraform/" >> .gitignore

# Safe way to pass secrets
export TF_VAR_db_password="production_password"
terraform apply
```

---

## 🎓 Recommended Learning Path

1. **Start with Level 0-1**: Understand principles and workflow
2. **Practice with 01-Lab**: Create resources, reference outputs, use string interpolation
3. **Move to Level 2-3**: 02-Lab-InputVariables teaches variables, loops, and conditionals
4. **Learn Modules (Level 4)**: 03-Lab-Modules shows code organization and reuse
5. **Understand State (Level 5)**: 05-Lab-RemoteState-backend covers state management
6. **Build Real Infrastructure (Level 6)**: 04-AzTerraform creates actual Azure resources

---

## 📚 Topics Checklist: What You Should Know

### Level 0-1: Foundation & Workflow
- [ ] What is Terraform and why use it
- [ ] Core principles (Idempotence, Immutability, DRY, etc.)
- [ ] What is a provider and how it works
- [ ] Terraform workflow stages (init → plan → apply → destroy)
- [ ] Drift detection (when does Terraform check?)
- [ ] How to handle drift in production
- [ ] Terraform file structure and conventions
- [ ] HCL syntax basics

### Level 2: Variables & Configuration
- [ ] Input variables (declaration vs assignment)
- [ ] Variable types (string, number, list, map, object)
- [ ] Variable validation and constraints
- [ ] Sensitive variables (hiding secrets)
- [ ] Local variables (locals)
- [ ] Output variables and outputs
- [ ] Variable precedence order
- [ ] terraform.tfvars vs *.auto.tfvars
- [ ] Environment variables (TF_VAR_*)
- [ ] Default values and validation rules

### Level 3: Loops & Conditionals
- [ ] count (iteration over lists)
- [ ] for_each (iteration over maps)
- [ ] Ternary operator (conditional expressions)
- [ ] Combining count/for_each with variables
- [ ] Splat operator (aws_instance.app[*].id)
- [ ] For expressions (transforming data)

### Level 4: Modules & Reusability
- [ ] What are modules and why use them
- [ ] Module structure (main.tf, variables.tf, output.tf)
- [ ] Local modules vs remote modules
- [ ] Calling modules with source and version
- [ ] Module inputs and outputs
- [ ] count/for_each on modules
- [ ] Module scoping and isolation

### Level 4.5: Environment Management
- [ ] Multi-environment strategies
- [ ] Separate directories per environment
- [ ] Workspaces (separate state, same code)
- [ ] Directory structure for teams
- [ ] Using -var-file flag for environments
- [ ] dev vs staging vs prod configurations
- [ ] Environment-specific variable files

### Level 5: State & Backends
- [ ] What is terraform.tfstate (JSON state file)
- [ ] Local vs remote state
- [ ] State file security (.gitignore)
- [ ] Remote backends (Azure, AWS, etc.)
- [ ] State locking (preventing concurrent changes)
- [ ] Workspaces and separate state files
- [ ] terraform state commands (list, show, mv, rm)
- [ ] State backup and recovery
- [ ] terraform.tfstate vs terraform.tfstate.backup

### Level 6: Azure Infrastructure
- [ ] Azure provider setup
- [ ] Common Azure resources
- [ ] Azure naming conventions
- [ ] Resource groups and subscriptions
- [ ] Azure authentication methods

### Level 7: Advanced Features
- [ ] Data sources (reading existing infrastructure)
- [ ] Resource dependencies (implicit vs explicit)
- [ ] depends_on meta-argument
- [ ] Lifecycle rules (prevent_destroy, create_before_destroy)
- [ ] ignore_changes
- [ ] Built-in functions (string, collection, type)
- [ ] Dynamic blocks
- [ ] Expressions and complex logic
- [ ] State locking and concurrency
- [ ] terraform import (bring existing resources into state)
- [ ] terraform console (interactive REPL)
- [ ] Terraform validation and testing

### Level 8: Production Best Practices
- [ ] Code organization and structure
- [ ] Drift detection pipeline (scheduled terraform plan)
- [ ] CI/CD integration
- [ ] Approval workflows
- [ ] Secrets management in Terraform
- [ ] Backup and disaster recovery
- [ ] Monitoring and alerting
- [ ] Version control strategy
- [ ] Team collaboration patterns
- [ ] Documentation standards

---

## ⚠️ Level 9: Troubleshooting, Security & Optimization

### 9.1 Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `Provider not found` | Provider not initialized | Run `terraform init` |
| `Resource already exists` | Manual resource created outside TF | Use `terraform import` to add to state |
| `State lock timeout` | Another apply running | Wait or `terraform force-unlock <id>` |
| `Invalid variable type` | Variable value doesn't match type | Check .tfvars for type mismatch |
| `Sensitive values in output` | Marked sensitive variable in output | Remove or mark output sensitive too |
| `Backend initialization failed` | Bad backend config or auth | Check backend credentials and permissions |

### 9.2 Debugging Tips

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan  # Verbose output
unset TF_LOG

# Save plan for inspection
terraform plan -out=debug.tfplan
terraform show debug.tfplan

# Check what Terraform sees in state
terraform state show aws_instance.web

# Validate with detailed errors
terraform validate -json  # JSON output for parsing
```

### 9.3 Version Constraints (versions.tf)

Control which provider versions your code works with:

```hcl
terraform {
  required_version = ">= 1.0, < 2.0"  # Terraform version
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"  # Major version 3, any minor/patch
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.0"  # Exact version
    }
  }
}
```

**Version constraint operators**:
- `= 3.0` → exactly 3.0
- `!= 2.0` → anything except 2.0
- `> 2.0` → greater than 2.0
- `>= 2.0` → 2.0 or newer
- `~> 2.0` → 2.x (2.0, 2.1, 2.99 but not 3.0)
- `~> 2.3.0` → 2.3.x (2.3.0, 2.3.5 but not 2.4.0)

### 9.4 Security Best Practices

**Secrets Management**:
```bash
# ❌ Never in code
variable "db_password" {
  default = "my_password"  # BAD!
}

# ❌ Never in .tfvars (might be committed)
# ✅ Use environment variables
export TF_VAR_db_password="actual_password"
terraform apply

# ✅ Or use secrets manager
variable "db_password" {
  type      = string
  sensitive = true
}
# In CI/CD: fetch from AWS Secrets Manager, set as env var
```

**State file security**:
```bash
# Ensure state is NOT committed
echo "terraform.tfstate*" >> .gitignore
echo ".terraform/" >> .gitignore

# Use remote backend with encryption
terraform {
  backend "azurerm" {
    # Azure encrypts state at rest automatically
    resource_group_name  = "tf-state"
    storage_account_name = "tfstate"
    container_name       = "tfstate"
  }
}

# Backup state regularly
terraform state pull > backup-$(date +%Y%m%d).tfstate
```

**Access control**:
```hcl
# Mark sensitive outputs
output "db_password" {
  value     = azurerm_mysql_server.main.administrator_login_password
  sensitive = true  # Won't appear in terraform apply output
}

# Restrict who can apply
# Use Azure AD/IAM to limit terraform apply to specific users
```

### 9.5 Performance Optimization

**Refresh state only when needed**:
```bash
terraform plan -refresh=false  # Skip cloud API call if state is recent
```

**Parallelize operations**:
```bash
terraform apply -parallelism=10  # Default 10, increase for faster apply
```

**Target specific resources**:
```bash
# Apply only one resource (skip others)
terraform apply -target=azurerm_resource_group.main
terraform apply -target=module.networking
```

**Avoid unnecessary state locking**:
```bash
# Read-only operations don't need lock
terraform plan    # No lock acquired
terraform state   # No lock acquired
terraform apply   # Acquires lock
```

### 9.6 Version Compatibility & Upgrades

**Check compatibility**:
```bash
# Show current versions
terraform version
terraform providers

# List available versions
terraform init -upgrade  # Upgrade to latest compatible
```

**Upgrade providers safely**:
```bash
# 1. Update versions.tf
variable "azurerm" {
  version = "~> 3.5"  # Was 3.0
}

# 2. Run init to download new version
terraform init

# 3. Plan to see if changes needed
terraform plan

# 4. Apply if all looks good
terraform apply
```

---

## 🚀 Production Checklist: Are You Ready?

Before deploying to production, ensure:

- [ ] Code is in Git repository with .gitignore configured
- [ ] All environment variables documented
- [ ] Remote backend configured with encryption
- [ ] State locking enabled
- [ ] Backup/disaster recovery plan in place
- [ ] Drift detection pipeline set up (scheduled terraform plan)
- [ ] Approval workflow in CI/CD (2 approvals for prod)
- [ ] Secrets NOT in .tfvars or code
- [ ] Sensitive outputs marked with `sensitive = true`
- [ ] Resource naming conventions documented
- [ ] Variables validated for constraints
- [ ] Documentation of all custom modules
- [ ] Team training on Terraform workflow
- [ ] Runbook for common operations (scaling, updates, rollback)
- [ ] Monitoring/alerting on infrastructure changes
- [ ] Regular state backups tested

---

## 📖 Additional Resources

- **Official Terraform Docs**: https://www.terraform.io/docs
- **HashiCorp Learn**: https://learn.hashicorp.com/terraform
- **Terraform Registry**: https://registry.terraform.io
- **Azure Provider Docs**: https://registry.terraform.io/providers/hashicorp/azurerm
- **Terraform Best Practices**: https://www.terraform.io/docs/language/state/backends

---

**Last Updated**: 2026-09-06  
**Repository**: d:\Codes\Terraform\00_AzureTerraform

---

## Summary: What's Covered in This Guide

✅ **Foundation**: Providers, principles, workflow stages  
✅ **Drift Detection**: How Terraform detects changes, production strategies  
✅ **Directory Structure**: Single and multi-environment layouts  
✅ **Environments**: Separate directories, workspaces, -var-file patterns  
✅ **Modules**: What they are, when to use, how to structure  
✅ **State & Backends**: Local vs remote, locking, security  
✅ **Advanced**: Data sources, dependencies, lifecycle, dynamic blocks  
✅ **Practical Examples**: Multi-env deployment, drift detection CI/CD  
✅ **Production Ready**: Security, testing, troubleshooting  
✅ **Complete Checklist**: 50+ concepts organized by level
