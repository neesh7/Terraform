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