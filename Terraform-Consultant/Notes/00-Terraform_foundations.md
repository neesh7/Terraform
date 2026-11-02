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
- Runs **locally** - does not call provider APIs or check remote state, so it won't catch things like an invalid VM size or a name that's already taken
- Requires `terraform init` first (it needs the provider schemas)
- Great as an early, fast check in CI/CD before `plan`; use `-json` for machine-readable output
```bash
terraform validate
# Success! The configuration is valid.
```

> 📝 **Note:** `validate` does not communicate with providers (no API calls), so it is not going to catch all errors. A config can pass `validate` and still fail at `plan`/`apply` — e.g. invalid SKU/region, name already taken, missing permissions, or quota limits.

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
- Resource order in your `.tf` files doesn't matter
- The resource graph is how Terraform achieves parallel execution
- Foundation for understanding resource dependencies

**Key Concept:** The graph is built from resource references - when one resource refers to another's attributes, Terraform automatically creates a dependency.

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
Two types of dependencies:
- **Implicit Dependencies (Automatic)** - a reference to another resource that Terraform already knows about
- **Explicit Dependencies (Manual)** - used when there's a dependency that Terraform can't automatically detect from resource references alone. Use `depends_on` to create an explicit dependency

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
2. **Use a remote backend with state locking** - (e.g. Azure Storage / S3 + DynamoDB) so two people or pipelines can't apply against the same state at once
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
- **Variables input** - `-var="name=value"`, `-var-file=dev.tfvars`, or env var `TF_VAR_name`
- **Auto-loaded var files** - `terraform.tfvars`, `terraform.tfvars.json`, `*.auto.tfvars`, `*.auto.tfvars.json`
- **Variable precedence (lowest → highest)** - default value → env vars (`TF_VAR_`) → `terraform.tfvars` → `*.auto.tfvars` (alphabetical) → `-var` / `-var-file` on the CLI (last one wins)
- **Logging** - `TF_LOG=TRACE|DEBUG|INFO|WARN|ERROR` enables logs, `TF_LOG_PATH=./tf.log` writes them to a file
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
- `TF_VAR_` env vars have the **lowest** precedence after defaults - `terraform.tfvars`, `*.auto.tfvars`, and `-var`/`-var-file` all override them
- `TF_LOG` without `TF_LOG_PATH` → logs go to stderr; `TF_LOG_PATH` alone does nothing
- To turn logging off, unset `TF_LOG` (or set it to `OFF`)
- Never commit secrets - use env vars (or a secrets manager) for credentials and sensitive variables

## Terraform Subcommands

### Core Workflow
- **`init`** - initializes the working directory: downloads providers & modules, configures the backend, creates/updates `.terraform.lock.hcl`. Safe to run multiple times
  - `-upgrade` (upgrade providers/modules within version constraints), `-reconfigure` (ignore existing backend config), `-migrate-state` (move state to a new backend), `-backend-config=<file>` (partial backend config), `-backend=false`
- **`fmt`** - rewrites `.tf` files to the canonical HCL style
  - `-recursive` (include subdirectories), `-check` (exit non-zero if unformatted - good for CI), `-diff` (show changes)
- **`validate`** - checks syntax and internal consistency. Needs `init`, doesn't call provider APIs
- **`plan`** - creates an execution plan (dry run)
  - `-out=<file>` (save plan), `-destroy` (preview a destroy), `-refresh-only` (only detect drift), `-replace=<addr>` (force recreate), `-target=<addr>`, `-detailed-exitcode` (0 = no changes, 1 = error, 2 = changes present)
- **`apply`** - executes the changes to reach the desired state. Prompts unless a saved plan file is given or `-auto-approve` is used
  - `-destroy` (same as `terraform destroy`), `-refresh-only`, `-replace=<addr>`, `-parallelism=n`
- **`destroy`** - destroys all resources managed by the configuration. Alias for `terraform apply -destroy`

### Inspecting State & Outputs
- **`show`** - human-readable view of the current state or a saved plan file (`terraform show myplan.tfplan`). `-json` for machine-readable output
- **`output`** - prints output values from the state. `terraform output <name>`, `-json`, `-raw` (plain string, good for scripts). Sensitive outputs are hidden as `(sensitive)` unless asked for by name or with `-json`
- **`console`** - interactive shell to test expressions and functions against the current state, e.g. `> cidrsubnet("10.0.0.0/16", 8, 1)`
- **`graph`** - outputs the dependency graph in DOT format. Visualize with Graphviz: `terraform graph | dot -Tsvg > graph.svg`

### State Management
- **`state`** - advanced state management (preferred over manually editing the state file)
  - `state list` (list resources in state), `state show <addr>` (details of one resource)
  - `state mv <src> <dest>` (rename/move a resource in state without recreating it)
  - `state rm <addr>` (stop managing a resource - the real resource is **not** destroyed)
  - `state pull` / `state push` (download / upload remote state), `state replace-provider`
- **`import`** - brings an existing real-world resource under Terraform management: `terraform import <addr> <id>`. Only writes to state - you must write the resource block yourself
  - Modern way (v1.5+): `import` block in config + `terraform plan -generate-config-out=generated.tf` to auto-generate the config
- **Moving resources (`move`)** - there is no `terraform move` command. Use `terraform state mv` (CLI), or the `moved` block in config (v1.1+, preferred - declarative and reviewed in the plan)
  ```hcl
  moved {
    from = azurerm_virtual_network.old
    to   = azurerm_virtual_network.main
  }
  ```
- **`force-unlock`** - manually removes a stuck state lock: `terraform force-unlock <LOCK_ID>`. Only use when you're sure no other operation is running

### Modules & Providers
- **`get`** - downloads/updates the modules referenced in the root module (`-update`). `init` already does this - `get` only handles modules, not providers or backend
- **`modules`** - lists the modules declared in the configuration (v1.10+), `-json` for machine-readable output
- **`providers`** - shows the providers required by the config and its modules
  - `providers lock` (update the lock file for multiple platforms), `providers mirror <dir>` (copy providers for offline/air-gapped use), `providers schema -json`
- **`version`** - shows the Terraform CLI version and the provider versions in use. Use the `required_version` setting to pin the CLI version

### Workspaces
- **`workspace`** - manages multiple state files for the same configuration (e.g. dev/test/prod). The default workspace is `default` and cannot be deleted
  - `workspace list`, `workspace show`, `workspace new <name>`, `workspace select <name>`, `workspace delete <name>`
  - Current workspace name is available in config as `terraform.workspace`

### HCP Terraform (Terraform Cloud)
- **`login`** - gets an API token for HCP Terraform / Terraform Enterprise and saves it to `credentials.tfrc.json`. `terraform login` (defaults to `app.terraform.io`) or `terraform login <hostname>`
- **`logout`** - removes the saved credentials for that host

### Testing
- **`test`** - runs `*.tftest.hcl` test files (v1.6+). Tests use `run` blocks with `command = plan` or `command = apply` and `assert` conditions. Resources created in tests are destroyed automatically afterwards

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
# ignore *.tfvars only if they hold secrets
*.tfvars
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

**2. Workspaces** - same code, one state file per workspace (`terraform workspace new dev`). Simple, but all envs share the same code and backend config, and it's easy to apply to the wrong one. Fine for short-lived or near-identical envs, not ideal for strict prod isolation.

**3. Same code + per-env tfvars** - `terraform apply -var-file=dev.tfvars`, with a separate backend for each env (`init -backend-config=dev.backend.hcl`).

**4. Tooling / platforms** - Terragrunt (keeps env configs DRY) or HCP Terraform workspaces linked to VCS branches/directories.

Large orgs also split state by **layer** (network → shared services → apps), so a change to an app never touches the network's state.

### Advantages
- **Smaller blast radius** - each env/project has its own state, so a bad change or broken state in dev can't affect prod
- **Isolation & access control** - different backends, credentials and permissions per env (e.g. only CI/CD can apply prod)
- **Reusability (DRY)** - modules are written once and reused, so envs differ only in their input values
- **Consistency** - dev, test and prod are built from the same modules, so "works in dev" usually means works in prod
- **Safe promotion** - test a change in dev → test → prod. Modules can be version-pinned per env
- **Faster plans & fewer lock conflicts** - smaller states mean quicker `plan`/`apply`, and teams don't block each other
- **Clear ownership** - each team owns its directory/state, which makes reviews and audits easier