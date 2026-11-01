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
