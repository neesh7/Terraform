# 4. Terraform Basics — *34:01*

| # | Topic | Duration |
|---|-------|----------|
| 1 | Using Terraform Providers | 04:13 |
| 2 | Configuration Directory | 01:32 |
| 3 | Lab: Terraform Providers | — |
| 4 | Multiple Providers | 03:51 |
| 5 | Lab: Multiple Providers | — |
| 6 | Using Input Variables | 03:47 |
| 7 | Understanding the Variable Block | 07:33 |
| 8 | Lab: Variables | — |
| 9 | Using Variables in Terraform | 04:58 |
| 10 | Lab: Using Variables in Terraform | — |
| 11 | Resource Attributes | 03:39 |
| 12 | Lab: Resource Attributes | — |
| 13 | Resource Dependencies | 02:11 |
| 14 | Lab: Resource Dependencies | — |
| 15 | Output Variables | 02:17 |
| 16 | Lab: Output Variables | — |

## Notes

### 1. Using Terraform Providers

A **provider** is a plugin that lets Terraform talk to a specific platform or service (AWS, Azure, GCP, Kubernetes, `local`, etc.). Each provider exposes a set of **resource types** and **data sources**.

When we run `terraform init` in a directory containing a configuration file, Terraform reads the providers referenced in the config, then **downloads and installs the matching provider plugins** from the [Terraform Registry](https://registry.terraform.io/).

#### Tiers of Providers

| Tier | Maintained by | Examples |
|------|---------------|----------|
| **Official** | HashiCorp | `aws`, `azurerm`, `google`, `local`, `random`, `kubernetes` |
| **Partner** | Third-party companies (verified by HashiCorp) | `digitalocean`, `heroku`, `bigip` |
| **Community** | Individual contributors / community | various community-published providers |

#### Where Plugins Are Installed

- Provider plugins are downloaded into a hidden directory in the working directory: **`.terraform/`** (under `.terraform/providers/...`).
- `terraform init` also writes a **`.terraform.lock.hcl`** dependency lock file recording the exact provider versions selected.

#### Provider Source Address

Providers are identified by a source address in the form:

```
[hostname]/<namespace>/<type>
```

- **hostname** *(optional)* — the registry host; defaults to `registry.terraform.io`.
- **namespace** — the organization that publishes the provider, e.g. `hashicorp`.
- **type** — the provider name, e.g. `aws`, `local`.

Example: `hashicorp/aws` → `registry.terraform.io/hashicorp/aws`.

By default, Terraform installs the **latest version** of a provider. You can pin a specific version using a `required_providers` block:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### 2. Configuration Directory

A Terraform **configuration directory** is any folder containing one or more `.tf` files. Terraform loads **all** `.tf` files in the directory together when you run `terraform plan` or `terraform apply`.

#### Naming Strategies

**Single file** — all blocks in one file:
```
project/
└── main.tf      ← resources, providers, variables, outputs all here
```

**Multiple files** — split by concern or by resource type (both are valid):

```
project/
├── main.tf          ← resource definitions
├── variables.tf     ← variable declarations
├── outputs.tf       ← output values
└── provider.tf      ← provider configuration
```

Or split by resource:
```
project/
├── local.tf         ← local_file resources
├── cat.tf           ← cat-related resources
└── ...
```

#### Conventional File Names

| File | Purpose |
|------|---------|
| `main.tf` | Main configuration — resource definitions |
| `variables.tf` | Input variable declarations |
| `outputs.tf` | Output value definitions |
| `provider.tf` | Provider configuration and `required_providers` block |

Terraform does not enforce these names — they are community convention. What matters is that all files are in the same directory and end in `.tf`.

#### Inspecting a Configuration Directory

To count **resource blocks** across all `.tf` files in a directory (without running `terraform init` or `terraform apply`):

```bash
grep -c 'resource' *.tf
```

This prints a per-file count of lines containing `resource`. To get the total across all files:

```bash
grep -h 'resource' *.tf | wc -l
```

> `terraform show` only reflects **deployed state**. If nothing has been applied yet, it shows nothing — always inspect the `.tf` files directly to understand what's configured.

### 3. Terraform Init → Plan → Apply Flow

#### `terraform init`
- Reads all `.tf` files in the directory.
- Identifies which providers are referenced (e.g. `local`, `random`).
- Downloads and installs those provider plugins into `.terraform/providers/`.
- Writes `.terraform.lock.hcl` locking the exact versions selected.

> No infrastructure is created yet — it's purely setup.

#### `terraform plan` *(optional but recommended)*
- Uses the downloaded plugins to calculate **what will be created / changed / destroyed**.
- Dry run only — nothing happens on disk or to real infra.

#### `terraform apply`
- Runs the plan again internally.
- Calls the provider plugins to **actually create the resources**.
- Writes the result to `terraform.tfstate` to track what was created.

#### Relationship at a glance

```
terraform init    →  downloads plugins    (prepares the tools)
terraform plan    →  calculates changes   (shows what will happen)
terraform apply   →  executes changes     (makes it real)
```

#### Analogy — think of it like cooking

| Command | Analogy |
|---------|---------|
| `terraform init` | Gathering your ingredients and tools |
| `terraform plan` | Reading the recipe and laying everything out |
| `terraform apply` | Actually cooking the dish |

### 4. Input Variables

Variables let you avoid hardcoding values in resource blocks, making configs reusable across environments.

#### Declaring a Variable (`variables.tf`)

```hcl
variable "filename" {
  type        = string
  default     = "pets.txt"
  description = "Path of the file to be created"
}

variable "content" {
  type        = string
  default     = "we love pets"
  description = "Content to write into the file"
}
```

- **`type`** — the data type (`string`, `number`, `bool`, `list`, `map`, `object`, `tuple`).
- **`default`** — fallback value if none is provided; omit it to force the user to supply a value at runtime.
- **`description`** — documents what the variable is for.

#### Referencing a Variable (`main.tf` / any `.tf`)

Use the `var.<name>` syntax to reference a declared variable:

```hcl
resource "local_file" "pet" {
    filename = var.filename
    content  = var.content
}
```

`var.filename` → Terraform looks up `variable "filename"` and substitutes its value.

#### Variable Types at a Glance

| Type | Example | Notes |
|------|---------|-------|
| `string` | `"/root/pets.txt"` | Plain text value |
| `number` | `1` | Integer or float |
| `bool` | `true` / `false` | Toggle flags |
| `any` | *(Default Value)* | No type constraint — Terraform infers the type |
| `list` | `["cat", "dog"]` | Ordered collection, accessed by index e.g. `var.pets[0]` |
| `map` | `{ pet1 = "cat", pet2 = "dog" }` | Key/value pairs, accessed by key e.g. `var.pets["pet1"]` |
| `object` | `{ name = "Whiskers", age = 3 }` | Complex structure with named attributes of mixed types |
| `tuple` | `["cat", 5, true]` | Complex structure — fixed-length, mixed types, accessed by index |

#### Type Constraints

The `type` argument enforces what kind of value is accepted. Terraform will throw an error at `plan`/`apply` time if the supplied value doesn't match.

**Primitive types** — single values:

```hcl
variable "filename" {
  type = string
}
variable "length" {
  type = number
}
variable "enabled" {
  type = bool
}
```

**Collection types** — multiple values of the **same** type:

```hcl
# list — ordered, accessed by index: var.prefix_list[0]
variable "prefix_list" {
  type    = list(string)
  default = ["Mr", "Mrs", "Dr"]
}

# map — key/value, accessed by key: var.file_permissions["pets.txt"]
variable "file_permissions" {
  type = map(string)
  default = {
    "pets.txt"  = "0700"
    "creds.txt" = "0400"
  }
}

# set — like list but unordered and no duplicate values
variable "allowed_ports" {
  type    = set(number)
  default = [22, 80, 443]
}
```

**Structural types** — multiple values of **mixed** types:

```hcl
# object — named attributes, each can have a different type
variable "pet_config" {
  type = object({
    name       = string
    age        = number
    vaccinated = bool
  })
  default = {
    name       = "Whiskers"
    age        = 3
    vaccinated = true
  }
}

# tuple — fixed-length, positional, mixed types: var.pet_details[0]
variable "pet_details" {
  type    = tuple([string, number, bool])
  default = ["cat", 5, true]
}
```

**`any`** — no constraint, Terraform infers the type from the value supplied:

```hcl
variable "anything" {
  type    = any
  default = "could be a string, number, list..."
}
```

> Prefer explicit types over `any` — it catches mismatches early and makes configs self-documenting.

#### Ways to Pass Variable Values

There are multiple ways to supply values to variables, listed in order of **precedence** (highest wins):

| Order | Method | Wins? |
|-------|--------|-------|
| 1 (lowest) | Environment Variables (`TF_VAR_`) | ❌ overridden by everything below |
| 2 | `terraform.tfvars` | ❌ overridden by 3 and 4 |
| 3 | `*.auto.tfvars` *(alphabetical order)* | ❌ overridden by 4 |
| 4 (highest) | `-var` or `-var-file` command-line flags | ✅ always wins |

**Example — all four set the same variable `filename`, value used is #4:**

```bash
# 1. Environment variable
export TF_VAR_filename="/root/cats.txt"
```

```hcl
# 2. terraform.tfvars
filename = "/root/pets.txt"
```

```hcl
# 3. variable.auto.tfvars
filename = "/root/mypet.txt"
```

```bash
# 4. CLI flag — this wins
terraform apply -var "filename=/root/best-pet.txt"
```

> When all four are set, Terraform uses `/root/best-pet.txt` because `-var` has the highest precedence.

**Command Line Flags (`-var`)** — pass values directly at runtime without any file:

```bash
terraform apply \
  -var "filename=/root/pets.txt" \
  -var "content=We love Pets!" \
  -var "prefix=Mrs" \
  -var "separator=." \
  -var "length=2"
```

Each `-var` flag overrides the `default` for that variable. Useful for quick one-off runs or CI pipelines.

**Environment Variables (`TF_VAR_`)** — set shell env vars prefixed with `TF_VAR_` then just run `terraform apply` with no flags:

```bash
export TF_VAR_filename="/root/pets.txt"
export TF_VAR_content="We love pets!"
export TF_VAR_prefix="Mrs"
export TF_VAR_separator="."
export TF_VAR_length="2"
terraform apply
```

- The naming convention is `TF_VAR_` + the variable name exactly as declared in `variables.tf`.
- Useful for **CI/CD pipelines** and **secrets** — avoids putting sensitive values in files that could be committed to version control.

**Variable Definition Files (`.tfvars`)** — put all values in a file, then just run `terraform apply`:

```hcl
# terraform.tfvars
filename  = "/root/pets.txt"
content   = "We love pets!"
prefix    = "Mrs"
separator = "."
length    = "2"
```

```bash
terraform apply
```

**Automatically loaded** — Terraform picks these up with no flag needed:

| Format | Filename |
|--------|----------|
| HCL | `terraform.tfvars` or `*.auto.tfvars` |
| JSON | `terraform.tfvars.json` or `*.auto.tfvars.json` |

For any other name, pass it explicitly with `-var-file`. The file can be named anything but must end in `.tfvars` or `.tfvars.json`:

```bash
terraform apply -var-file="dev.tfvars"
terraform apply -var-file="prod.tfvars"
terraform apply -var-file variables.tfvars
```

> `.tfvars` files should be added to `.gitignore` if they contain sensitive values like passwords or tokens.

#### Hardcoded vs Variables vs `.tfvars`

| Approach | Flexibility | When to use |
|----------|-------------|-------------|
| Hardcoded values | None — must edit code to change | Never for real infra |
| `var.<name>` with defaults | Medium — defaults can be overridden | Good for single environments |
| `.tfvars` files per environment | Full — zero code changes | Best for dev/staging/prod |

```bash
# apply with a specific var file per environment
terraform apply -var-file="dev.tfvars"
terraform apply -var-file="prod.tfvars"
```

> **Rule of thumb:** If a value ever needs to differ between environments, runs, or users — make it a variable. Hardcode only what is truly constant and universal.