# Terraform Fundamentals

Terraform is created by HashiCorp and follows a declarative approach (defining what the infra should look like). It is based on HCL (HashiCorp Configuration Language — basically the language/syntax).

IaC -> Turning infra into code, standardized workflow, platform agnostic and more...

## Benefits of Terraform
1. Version control and auditability
2. Automation and efficiency
3. Scalability and flexibility
4. Collaboration
5. Consistency and repeatability
6. Code reusability

## What is IaC and how does Terraform help us achieve it?
Terraform is an IaC tool using which we define the desired state of our infra in config files instead of the steps to achieve that state. Terraform compiles those config files together and sends requests to the target platform using APIs (the provider's responsibility) to get the desired infra running. As our infra lives in code (code is the main source of truth), it is easily maintainable and can be governed as well.

## HCL Syntax
```hcl
<BLOCK-TYPE> "<BLOCK-LABEL (resource type)>" "<BLOCK-LABEL (name, for Terraform internal reference)>" {
  # args (basically properties)
  key = value
}
```

## HCL Style Guide
1. Use `#` for single and multi-line comments
2. Use underscores to separate multiple words
3. Indentation = 2 spaces for each nesting level
4. Align equals signs for values on consecutive lines
5. Use empty lines to separate groups of arguments in a block
6. Run `terraform fmt` when done writing code
7. Avoid hardcoding values

## Resource Referencing
1. Create dynamic configurations (using the output of one resource as input/args to another)
2. Automatic dependency mapping (by building a DAG)
3. Resource identifiers

## Core Components
1. **Terraform Core** - CLI tool
2. **Providers** - translate HCL into API calls (plugin based)
3. **Resources** - the actual infra that we want to provision
4. **State** - records the current state of infra (basically the main source of truth)
5. **Modules** - reusable infra templates

## Terraform Editions (1 & 2 are part of the exam)
1. **Terraform Community** - command-line based, the one we use
2. **HCP Terraform** - formerly Terraform Cloud
3. **Terraform Enterprise** - self-hosted and managed

## Imperative vs Declarative
**Imperative approach:** we tell the step-by-step execution needed to get to the end goal.
Example: Step 1 (Build VM) -> Step 2 (Configure VM) -> Step 3 (Attach to Network)

**Declarative approach:** we just define the end result in a config file, e.g. "I want a VM with these properties" — that's it.
Basically focuses on defining what you want the outcome to be, not how to achieve it.

# Terraform Workflow

## Terraform Workflow (Official)
1. Write (create or modify config files)
2. Plan
3. Apply

**In practice:**
1. Write (create or modify config files)
2. Init (download providers & modules, backend management, creates/updates lock file `.terraform.lock.hcl`)
3. Plan (preview changes before apply)
4. Apply (actually provision the infra)

**My custom workflow:**
Write Config Files -> FMT -> Init -> Validate -> Plan -> Apply/Destroy

## Init Stage
- Downloads providers & modules, handles backend management, creates/updates the lock file `.terraform.lock.hcl`
- **Lock file purpose** - it locks the provider versions and lives at the same level as the config files
- Terraform uses the `.terraform` directory to store the project's providers and modules:
  ```
  .terraform/
  ├── providers/
  └── modules/
  ```
- Do not check in the `.terraform` directory to version control. It can be safely deleted to keep the project lightweight (`terraform init` recreates it)

## Validate (`terraform validate`)
- Checks whether the configuration is syntactically valid and internally consistent (correct argument names/types, valid references, required arguments present)
- Runs **locally** - does not call provider APIs or check remote state, so it won't catch all errors. A config can pass `validate` and still fail at `plan`/`apply` — e.g. invalid SKU/region, name already taken, missing permissions, or quota limits
- Requires `terraform init` first (it needs the provider schemas)
- Great as an early, fast check in CI/CD before `plan`; use `-json` for machine-readable output
```bash
terraform validate
# Success! The configuration is valid.
```

## Plan Stage
- `terraform plan` generates an execution plan showing the changes Terraform will make to real-world resources in order to match the desired state configuration
- Performs a dry run of your changes so you can review them
- **Notations:** `+` (create), `~` (update in-place), `-` (destroy)

### Saving a Plan
- Guarantees execution for review and approval workflows
- **Benefit:** the exact saved plan will be executed, no surprises
- **Review and approval workflow:** save the plan, have it reviewed and approved, then apply later with confidence

How to save a plan?
```bash
terraform plan -out=myplan.tfplan
```

## Resource Graph (DAG)
So what actually happens when you run `terraform plan`?
- Terraform automatically builds a dependency graph from your configuration to determine the order in which to create, update, or destroy resources
- **DAG = Directed Acyclic Graph** - each resource is a node, each dependency is a one-way edge ("A depends on B"), and there are no cycles (A → B → A is an error: `Cycle: ...`)
- **How Terraform builds it** - edges come from exactly two sources:
  1. **Implicit dependencies** - an attribute reference in an argument, e.g. `subnet_id = azurerm_subnet.web.id` adds the edge VM → Subnet
  2. **Explicit dependencies** - `depends_on = [azurerm_xxx.yyy]`, for dependencies Terraform can't see from references
- Resource order in your `.tf` files doesn't matter
- The resource graph is how Terraform achieves parallel execution
- Foundation for understanding resource dependencies

**Key Concept:** The graph is built from dependencies - implicit (one resource references another's attributes) and explicit (`depends_on`). No reference and no `depends_on` = no edge, so the two resources run in parallel.

Example graph (arrows point to what a resource depends on):
```
              Virtual Network
            ↑        ↑        ↑
         Subnet   Subnet   Subnet
            ↑        ↑        ↑
           VM       VM  →    VM
```
- Vertical arrows = implicit dependencies (VM references Subnet, Subnet references VNet)
- Horizontal arrow (VM → VM) = explicit dependency via `depends_on`, where there's no attribute reference between them

### Dependencies
**Implicit** (automatic, from references) vs **explicit** (`depends_on`, for hidden dependencies). Details and comparison → [01 › Explicit Dependency / Implicit vs Explicit](01-Terraform_Configurations.md)

### Parallel Resource Operations
How Terraform walks the graph:
- **Parallel Execution** - processes nodes as soon as their dependencies are satisfied. Non-dependent resources are created/modified simultaneously
- **Default Configuration** - by default, Terraform manages 10 operations in parallel, but this can be modified using the `-parallelism` flag (`terraform apply -parallelism=5`)
- **When to Change Parallelism** - if you're running into API rate limiting issues, or for debugging/troubleshooting purposes. Most users never need to change this setting

## Apply Stage (`terraform apply`)
`terraform apply` tells Terraform to provision real infrastructure.
- **What Does It Do?** - it takes your configuration and creates the resources as defined in it. This is where Terraform makes changes to your infrastructure
- **Refreshes State** - `terraform apply` runs a plan first to compare your existing infrastructure to your desired state. By default, Terraform will prompt you to proceed with the proposed changes
- **When Do You Use It?** - anytime you want to make changes to your infrastructure. This includes adding, modifying, or destroying real-world resources

### Understanding Apply Operations
What happens behind the scenes when Terraform modifies your infrastructure:
- **State Locking** - Terraform locks the state file during apply to prevent concurrent modifications
- **State Updates** - the state file is updated after each resource is successfully created/modified/destroyed
- **No Automatic Rollback** - if a resource fails during apply, Terraform does not roll back previous successful changes. They remain in place
- **Respects Dependencies** - apply follows the resource graph: resources are created/modified in dependency order (and destroyed in reverse order), with independent resources running in parallel

### Ways to Run `terraform apply`
- **Standard Apply** - runs a plan, then prompts for confirmation
  ```bash
  terraform apply
  # Confirm (Y/N):
  ```
- **Apply a Saved Plan** - executes the exact saved plan (no confirmation prompt)
  ```bash
  terraform apply myplan.tfplan
  ```
- **Apply & Auto Approve** - skips the confirmation prompt, use carefully
  ```bash
  terraform apply -auto-approve
  ```
- `-input=false` is also helpful for automation/CI/CD pipelines

### Best Practices for `terraform apply`
1. **Always review the plan first** - save it with `terraform plan -out=tfplan`, get it reviewed, then run `terraform apply tfplan` so exactly what was approved gets applied
2. **Use a remote backend with state locking** - (e.g. Azure Storage blob lease / S3 `use_lockfile`) so two people or pipelines can't apply against the same state at once
3. **Avoid `-auto-approve` outside of pipelines** - only use it in CI/CD where a reviewed saved plan or an approval gate already exists; never casually on production
4. **Apply through CI/CD, not from laptops** - run `fmt`, `validate`, and `plan` in the pipeline with consistent credentials, provider versions (`.terraform.lock.hcl`), and an audit trail
5. **Keep changes small and target the right environment** - smaller applies reduce blast radius (remember: no automatic rollback); double-check the workspace/backend/var-file before applying, and use `-target` only for exceptional fixes

## Destroy Stage (`terraform destroy`)
`terraform destroy` terminates resources managed by Terraform in the current workspace or working directory.
- **Using the Destroy Command** - explicitly destroys all infrastructure being managed by Terraform. This operation does prompt for confirmation before proceeding, and shows the destruction plan first
- **Removing Individual Resources from your Configuration** - delete resource blocks from your `.tf` files and then run `terraform apply`. Terraform detects the removed resources and destroys the real-world resources
- **State File Updates** - once a resource is destroyed, Terraform removes it from the state file as well, since it is no longer being managed

### Destroying a Single Resource
You can target specific resources, if needed, using the destroy command:
```bash
terraform destroy -target=<resource_type>.<resource_name>
# e.g. terraform destroy -target=azurerm_virtual_machine.web
```

> ⚠️ **WARNING:** Destroy operations are irreversible. Always review the plan carefully.

# Terraform CLI

```bash
terraform <subcommand> [options or flags]
```

## CLI Basics (Exam Focus - Terraform Associate 004)
- `terraform -help` / `terraform <subcommand> -help` - list commands / show help for a specific command
- `-chdir=<dir>` - global option to run a command against another directory: `terraform -chdir=envs/dev plan`
- **Variables input** - `-var="name=value"`, `-var-file=dev.tfvars`, or env var `TF_VAR_name`. Auto-loaded files and the full **precedence order** → [01 › Assigning Values & Precedence](01-Terraform_Configurations.md)
- **Logging** - `TF_LOG` / `TF_LOG_PATH` (see the env var table below)
- **Automation** - `-input=false` (no prompts), `-auto-approve` (skip confirmation), `-no-color`, `-json` (machine-readable output)
- **Deprecated commands to know** - `terraform refresh` → use `terraform apply -refresh-only`; `terraform taint` → use `terraform apply -replace=<addr>`

## Environment Variables with the CLI
Environment variables let you configure Terraform's behavior and pass values without changing code or typing flags every time.

**How to set them:**
```bash
# Bash / Linux / macOS (current session)
export TF_VAR_location="eastus"
unset TF_VAR_location

# Only for a single command
TF_LOG=DEBUG terraform plan
```
```powershell
# PowerShell (Windows)
$env:TF_VAR_location = "eastus"
Remove-Item Env:TF_VAR_location
```

**Common Terraform environment variables:**

| Variable | Purpose | Example |
|----------|---------|---------|
| `TF_VAR_<name>` | Sets an input variable (name must match the variable name, case-sensitive) | `TF_VAR_location=eastus` |
| `TF_LOG` | Enables detailed logs: `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR` (`JSON` = TRACE in JSON format) | `TF_LOG=DEBUG` |
| `TF_LOG_PATH` | Writes logs to a file (needs `TF_LOG` set too) | `TF_LOG_PATH=./terraform.log` |
| `TF_LOG_CORE` / `TF_LOG_PROVIDER` | Separate log levels for Terraform core vs providers | `TF_LOG_PROVIDER=TRACE` |
| `TF_INPUT` | `false`/`0` disables interactive prompts (same as `-input=false`) | `TF_INPUT=0` |
| `TF_CLI_ARGS` | Extra flags added to every command | `TF_CLI_ARGS="-no-color"` |
| `TF_CLI_ARGS_<cmd>` | Extra flags for one specific command only | `TF_CLI_ARGS_plan="-parallelism=5"` |
| `TF_WORKSPACE` | Selects the workspace (instead of `terraform workspace select`) | `TF_WORKSPACE=dev` |
| `TF_DATA_DIR` | Changes the location of the `.terraform` directory | `TF_DATA_DIR=/tmp/tfdata` |
| `TF_IN_AUTOMATION` | Any non-empty value tweaks output for CI (hides "next step" hints) | `TF_IN_AUTOMATION=true` |
| `TF_PLUGIN_CACHE_DIR` | Shared provider cache, so providers aren't re-downloaded for every project | `TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache` |
| `TF_CLI_CONFIG_FILE` | Custom location for the CLI config file (`.terraformrc` / `terraform.rc`) | `TF_CLI_CONFIG_FILE=./dev.tfrc` |
| `TF_TOKEN_<host>` | API token for HCP Terraform / TFE (dots → `_`), instead of `terraform login` | `TF_TOKEN_app_terraform_io=...` |

**Passing complex types with `TF_VAR_`** - list/map/object values are written in HCL syntax:
```bash
export TF_VAR_address_space='["10.0.0.0/16"]'
export TF_VAR_tags='{ env = "dev", owner = "neesh" }'
```

**Provider credentials** - providers also read their own env vars, which keeps secrets out of `.tf` files:
```bash
# AzureRM (service principal)
export ARM_CLIENT_ID="..."  ARM_CLIENT_SECRET="..."  ARM_TENANT_ID="..."  ARM_SUBSCRIPTION_ID="..."
# AWS
export AWS_ACCESS_KEY_ID="..."  AWS_SECRET_ACCESS_KEY="..."  AWS_REGION="us-east-1"
```

**Exam points to remember:**
- `TF_VAR_` env vars have the **lowest** precedence after defaults (full order in 01)
- `TF_LOG` without `TF_LOG_PATH` → logs go to stderr; `TF_LOG_PATH` alone does nothing (debugging details → [05 › section 9](05-Terraform_Security.md))
- To turn logging off, unset `TF_LOG` (or set it to `OFF`)
- Never commit secrets - use env vars (or a secrets manager) for credentials and sensitive variables (security view → [05 › section 4](05-Terraform_Security.md))

## Terraform Subcommands
Every subcommand with its flags and a one-line explanation is in **[Terraform-Commands.md](Terraform-Commands.md)** (the single command reference). The workflow commands (`init`, `validate`, `plan`, `apply`, `destroy`) are explained above, state commands in [02](02-Terraform_State.md), and `import`/`moved`/`removed` in [03 › section 6](03-Making-Code-Reusable.md).

## Terraform File Structure
Terraform loads **all `.tf` files in a directory** together and treats them as one configuration. File names don't matter to Terraform, but splitting them by purpose is the standard convention for readability.

### Files You Write
- **`main.tf`** - the core resources (and module calls)
- **`variables.tf`** - `variable` blocks: input names, types, descriptions, defaults, validation
- **`outputs.tf`** - `output` blocks: values to show after apply or pass to other configs
- **`providers.tf`** - `provider` blocks (region, features, aliases)
- **`versions.tf`** / **`terraform.tf`** - `terraform {}` block: `required_version`, `required_providers`, `backend`
- **`locals.tf`** - `locals` block for computed/reused values (optional)
- **`data.tf`** - `data` sources (optional)
- **`terraform.tfvars`** - actual values for variables. Loaded automatically, along with `*.auto.tfvars`. Others are passed with `-var-file=prod.tfvars`

### Files Terraform Generates
- **`.terraform/`** - downloaded providers and modules (created by `init`). Never commit
- **`.terraform.lock.hcl`** - locks exact provider versions + checksums so everyone uses the same versions. **Commit it**
- **`terraform.tfstate`** - the state file: maps config to real resources. May contain secrets, so keep it in a remote backend, not in git
- **`terraform.tfstate.backup`** - the previous state, written before each change. Never commit
- **`*.tfplan`** - saved plan files (`plan -out`). Never commit

### `.gitignore`
```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
# ignore *.tfvars only if they hold secrets (or only the secret ones, e.g. secrets.auto.tfvars)
*.tfvars
*.tfvars.json
override.tf
override.tf.json
*_override.tf
```

### Managing Multiple Environments in Organizations
Organizations run the same infrastructure in several environments (dev, test, staging, prod) and often across several projects/teams. Common approaches:

**1. Directory per environment (most common)** - reusable code lives in `modules/`, and each environment is a small root module that calls those modules with its own values, backend and state.
```text
terraform/
├── modules/              # reusable building blocks
│   ├── network/
│   ├── compute/
│   └── database/
├── projectx/
│   ├── dev/
│   │   ├── main.tf       # calls ../../modules/*
│   │   ├── backend.tf    # separate state per env
│   │   └── terraform.tfvars
│   ├── test/
│   └── prod/
└── projecty/
    ├── dev/
    └── prod/
```

**2. Workspaces** - same code, one state file per workspace (`terraform workspace new dev`). Simple, but all envs share the same code and backend config, and it's easy to apply to the wrong one. Fine for short-lived or near-identical envs, not ideal for strict prod isolation (full pros/cons → [02 › Workspaces](02-Terraform_State.md)).

**3. Same code + per-env tfvars** - `terraform apply -var-file=dev.tfvars`, with a separate backend for each env (`init -backend-config=dev.backend.hcl`).

**4. Tooling / platforms** - Terragrunt (keeps env configs DRY) or HCP Terraform workspaces linked to VCS branches/directories. HCP Terraform sets variables per workspace, and **variable sets** share common values across workspaces.

**5. CI/CD pipelines** - inject values as `TF_VAR_<name>` env vars. Secrets come from Key Vault or the pipeline's secret store, never from committed `.tfvars`.

Large orgs also split state by **layer** (network → shared services → apps), so a change to an app never touches the network's state.

### Advantages
- **Smaller blast radius** - each env/project has its own state, so a bad change or broken state in dev can't affect prod
- **Isolation & access control** - different backends, credentials and permissions per env (e.g. only CI/CD can apply prod)
- **Reusability (DRY)** - modules are written once and reused, so envs differ only in their input values
- **Consistency** - dev, test and prod are built from the same modules, so "works in dev" usually means works in prod
- **Safe promotion** - test a change in dev → test → prod. Modules can be version-pinned per env
- **Faster plans & fewer lock conflicts** - smaller states mean quicker `plan`/`apply`, and teams don't block each other
- **Clear ownership** - each team owns its directory/state, which makes reviews and audits easier