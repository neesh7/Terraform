# 6. Working with Terraform — *37:54*

| # | Topic | Duration |
|---|-------|----------|
| 1 | Terraform Commands | 05:28 |
| 2 | Lab: Terraform Commands | — |
| 3 | Mutable vs Immutable Infrastructure | 05:57 |
| 4 | LifeCycle Rules | 05:48 |
| 5 | Lab: Lifecycle Rules | — |
| 6 | Datasources | 04:24 |
| 7 | Lab: Datasources | — |
| 8 | Meta-Arguments | 01:30 |
| 9 | Count | 06:18 |
| 10 | for-each | 03:13 |
| 11 | Lab: Count and for each | — |
| 12 | Version Constraints | 05:16 |
| 13 | Lab: Version Constraints | — |

## Notes

### Useful Alias
```bash
alias tf="terraform"
```

### Core Terraform Commands

#### Initialization & Validation
- **`tf init`** — Initialize a Terraform working directory (downloads required providers & modules)
- **`tf validate`** — Validates the Terraform configuration for syntax errors

#### Planning & Execution
- **`tf plan`** — Creates an execution plan (shows what changes will be made)
- **`tf apply`** — Applies the Terraform configuration to create/update infrastructure
- **`tf apply -refresh-only`** — Refreshes the state without making any changes to resources
- **`tf destroy`** — Destroys all infrastructure managed by Terraform (removes all resources defined in configuration)

#### Code Formatting & Display
- **`tf fmt`** — Formats Terraform code into canonical format (applies to all .tf files)
- **`tf show`** — Prints the current state of the Terraform infrastructure
- **`tf show -json`** — Outputs current state in JSON format for programmatic access

#### State Management
- **`tf state show <resource-type>.<resource-name>`** — Displays details of a specific resource (e.g., `tf state show local_file.file` to view the file resource attributes and ID)
- **`tf state list`** — Lists all resources in the state file
- **`tf state rm <resource>`** — Removes a resource from state without destroying it

#### Provider & Output Management
- **`tf providers`** — Lists all providers required by the configuration
- **`tf providers mirror /path/to/directory`** — Mirrors providers locally (e.g., `tf providers mirror /root/terraform/new_local_file`)
- **`tf output`** — Displays all output variables
- **`tf output variable-name`** — Displays specific output variable value

### Infrastructure Visualization
- **`tf graph`** — Generates a DOT format graph of resource dependencies
- **`pt install graphviz -y`** — Installs Graphviz (required for visualization)
- **`tf graph | dot -Tsvg > graph.svg`** — Creates an SVG visualization of the resource dependency graph

### Important: Validate vs Apply Behavior
**`tf validate` ≠ Guaranteed Success**

`tf validate` performs only basic syntax and argument checking—it does NOT verify whether your values are appropriate or sufficient for actual resource creation. Even if validation passes, `tf apply` can still fail because:
- `tf apply` actually interacts with the provider to provision resources
- Missing or incorrect values may only be caught at runtime during resource provisioning
- Provider-level constraints and requirements are only enforced during `apply`, not `validate`

**Always test with `tf plan` and `tf apply` to catch real-world issues.**


# Mutable and Immutable Infra

## Mutable Infrastructure
Resources are **modified in-place** when changes are needed. Existing infrastructure is updated with new configurations.
- **Example:** SSH into a server and manually update configuration files, install packages, or change settings
- **Risk:** Configuration drift — actual state diverges from intended state over time
- **In Terraform:** By default, most resources follow a mutable approach (e.g., updating tags, changing instance types)

## Immutable Infrastructure
Resources are **replaced entirely** instead of being modified. When a change is needed, the old resource is destroyed and a new one is created with the updated configuration.
- **Example:** Instead of updating a server, terminate it and launch a new one with the desired configuration
- **Benefit:** Ensures consistency, reproducibility, and state stays in sync with code
- **In Terraform:** Use `create_before_destroy` lifecycle rule to force resource replacement rather than in-place updates

## Terraform Perspective
Terraform is designed to work best with **immutable infrastructure patterns** because:
- **State Management:** Immutable approach ensures terraform.state always matches actual infrastructure
- **Predictability:** Replacement is more predictable than modification (no hidden side effects)
- **Rollback:** Easier to roll back by reapplying previous configuration
- **Compliance & Auditing:** Clear record of infrastructure changes with no manual drift
- **Lifecycle Control:** Use lifecycle rules (e.g., `create_before_destroy = true`) to enforce immutability where needed

---

# Lifecycle Rules

Lifecycle rules control how Terraform manages resource creation, updates, and deletion. They are specified in a `lifecycle` block within a resource.

## Common Lifecycle Meta-Arguments

| Order | Option | Description |
|-------|--------|-------------|
| 1 | `create_before_destroy` | Create the new resource first, then destroy the older one. Useful for zero-downtime deployments |
| 2 | `prevent_destroy` | Prevents Terraform from destroying a resource. Useful for critical resources like databases |
| 3 | `ignore_changes` | Ignores changes to specified resource attributes. Can target specific attributes or all attributes |

## Usage Examples

### create_before_destroy
```hcl
lifecycle {
  create_before_destroy = true
}
```
- Creates replacement resource before terminating old one
- Ensures no downtime during updates
- Critical for load-balanced applications

### prevent_destroy
```hcl
lifecycle {
  prevent_destroy = true
}
```
- Blocks accidental deletion of important resources
- `terraform destroy` will fail if resource has this rule
- Must be manually removed to allow destruction

### ignore_changes
```hcl
lifecycle {
  ignore_changes = [tags]  # Ignore specific attribute
  # or
  ignore_changes = all     # Ignore all changes
}
```
- Useful when external systems modify resource attributes
- Prevents Terraform from forcing changes back to state
- Example: Ignore tags added by auto-scaling or monitoring tools

## Quick Reference
- **`create_before_destroy`** — Zero-downtime updates (new → old)
- **`prevent_destroy`** — Blocks accidental deletion of critical resources
- **`ignore_changes`** — Allows external systems to modify resource attributes without Terraform forcing revert

## Important: create_before_destroy Limitations

### Local File Resources
When `create_before_destroy` is used with `local_file` resources, there's a critical constraint:
- If the `filename` argument remains the same, Terraform **cannot create both files simultaneously**
- Terraform will attempt to create the new file first, but since the path is identical, it immediately deletes the existing file
- This defeats the purpose of `create_before_destroy` (zero-downtime)

**Workaround:** Use unique filenames or enable recreation on change, not for zero-downtime purposes.

### Random String Resources
The `random_string` resource **does not have this limitation** because:
- It only exists in Terraform state (no physical file path conflict)
- Multiple instances can be created and destroyed without file path collisions
- `create_before_destroy` works as intended with random resources

### Example Behavior
1. File is deleted during `terraform apply` with `create_before_destroy`
2. Next `terraform apply` will recreate the local_file since it no longer exists
3. Random string updates smoothly without file conflicts

---

# Random Provider & Keepers

## Keepers Argument
The `keepers` argument in the random provider is a map-type argument that forces resource recreation when its values change.

**How it works:**
- Accepts arbitrary key/value pairs
- Modifying any key/value triggers resource destruction and recreation
- Example: `keepers = { length = var.string_length }`
- If `length` changes from `10` to `12`, `terraform apply` will destroy the old random_string and create a new one with the updated length

**Use Cases:**
- Force random value regeneration when dependent variables change
- Ensure resources are recreated when specific conditions are met
- Maintain consistency between input variables and generated values

**Example:**
```hcl
resource "random_string" "example" {
  length  = 16
  keepers = {
    length = var.string_length  # If this variable changes, resource is recreated
  }
}
```
# Datasources in Terraform

## Resources vs Data Sources

| Aspect | Resource | Data Source |
|--------|----------|------------|
| **Keyword** | `resource` | `data` |
| **Operation** | Creates, Updates, Destroys Infrastructure | Only Reads Infrastructure |
| **Also Called** | Managed Resources | Data Resources |

## Key Differences

### Resources (Managed Resources)
- **Syntax:** `resource "provider_type" "name" { ... }`
- **Purpose:** Create and manage actual infrastructure
- **State:** Tracked in `terraform.state`
- **Lifecycle:** Can be created, updated, and destroyed by Terraform
- **Example:** `resource "aws_instance" "web" { ... }`

### Data Sources (Data Resources)
- **Syntax:** `data "provider_type" "name" { ... }`
- **Purpose:** Fetch information about existing infrastructure without managing it
- **State:** References are stored in state, but data source doesn't control the actual resource
- **Lifecycle:** Read-only; cannot be created or destroyed by Terraform
- **Example:** `data "aws_ami" "ubuntu" { ... }` (queries existing AMIs)

## Use Cases for Data Sources
- **Lookup existing resources:** Get details of resources created outside Terraform
- **Query cloud provider data:** Fetch available machine images, availability zones, security groups
- **Reference infrastructure:** Use output from data sources in resource definitions
- **Read-only access:** Access information without risking accidental modification

## Example Usage

```hcl
# Data source - reads existing file without managing it
data "local_file" "dog" {
    filename = "/root/dog.txt"
}

# Resource - uses data source output
resource "local_file" "pet" {
    filename = "/root/pet.txt"
    content  = data.local_file.dog.content  # Reference data source
}
```

**Key Point:** The data source `local_file.dog` only reads the file—it doesn't create or manage it. The resource `local_file.pet` then uses that data to create a new file.

# Meta Arguments
Meta-arguments are special configuration options that apply to ANY resource type (not provider-specific) and control how Terraform manages resource behavior—like creating multiple instances (count, for_each), handling dependencies (depends_on), specifying providers, and controlling lifecycle.

---

## count Meta-Argument

### What is count?
`count` is a meta-argument that creates **multiple instances of the same resource** based on a count value. Each instance is identified by an index number (0, 1, 2, ...).

**Syntax:**
```hcl
resource "resource_type" "name" {
  count = <number>  # Creates that many instances
  # ... other arguments
}
```

### Accessing count.index
Use `count.index` to reference the current iteration number (0-based index) in attributes.

**Syntax:**
```hcl
resource "local_file" "pet" {
  filename = var.filenames[count.index]  # Access list element by index
  count    = 3                             # Creates 3 instances
}
```

### Real-World Example

#### variables.tf
```hcl
variable "filenames" {
  default = [
    "/root/pets.txt",
    "/root/dogs.txt",
    "/root/cats.txt"
  ]
}
```

#### main.tf
```hcl
resource "local_file" "pet" {
  filename = var.filenames[count.index]  # pet[0] → pets.txt, pet[1] → dogs.txt, etc.
  content  = "This is a pet file"
  count    = 3                            # Creates 3 resources
}
```

#### Result
Three resource instances are created:
- `local_file.pet[0]` → `/root/pets.txt`
- `local_file.pet[1]` → `/root/dogs.txt`
- `local_file.pet[2]` → `/root/cats.txt`

### count vs Hardcoding

| Approach | Code Required | Flexibility | Maintainability |
|----------|---------------|-------------|-----------------|
| **Hardcoding** | Write 3 separate resources | Low (change count = rewrite) | Poor |
| **count** | 1 resource with count | High (change count = auto-adjust) | Excellent |

### count.index vs count
- **`count.index`** — The current iteration number (0, 1, 2, ...)
- **`count`** — The count object itself (contains index and other metadata)

### Use Cases
- Create multiple instances of the same resource
- Use list variables to drive resource creation
- Dynamic resource replication based on variable length
- Avoid code duplication when similar resources are needed

---

## Problems with count Meta-Argument

### 1. Index-Based References Break with List Changes
When you remove an item from the middle of a list, all subsequent resources shift index positions and get **unnecessarily destroyed and recreated**.

**Example:**
```
Original: [pets.txt, dogs.txt, cats.txt]  → pet[0], pet[1], pet[2]
Remove dogs.txt: [pets.txt, cats.txt]     → pet[0], pet[1]

Problem: Terraform thinks pet[1] changed from dogs.txt → cats.txt
Result: Unnecessary destruction and recreation of pet[1]
```

### 2. Non-Intuitive Resource Names
Resources are referenced by index numbers (pet[0], pet[1], pet[2]) instead of meaningful identifiers, making code hard to read and maintain.

### 3. Difficult with Complex Data Structures
- Works poorly with maps and objects
- Best suited only for simple lists
- Limited flexibility with dynamic data

### 4. Resource Churn on Changes
Removing items from the middle causes cascading index shifts, leading to unintended resource destruction.

---

## Better Alternative: for_each ✅
Use `for_each` instead of `count` when list items might be added/removed:

```hcl
resource "local_file" "pet" {
  for_each = toset(var.filenames)
  filename = each.value
  content  = "Pet file"
}

# Result: pet["pets.txt"], pet["dogs.txt"], pet["cats.txt"]
# Remove dogs.txt → Only that specific resource is destroyed ✓
```

**Key Advantage:** `for_each` uses keys/identifiers, not index positions, so removing items doesn't break references.

---

## count vs for_each

| Feature | count | for_each |
|---------|-------|----------|
| **Reference Style** | Index-based (pet[0]) | Key-based (pet["name"]) |
| **Removing Items** | Breaks (causes churn) | Safe (only removes that item) |
| **Readability** | Poor (hard to identify) | Excellent (clear identifiers) |
| **Best For** | Fixed-size lists | Dynamic, changing lists |

---

# Version Constraints

## What are Version Constraints?
Version constraints specify which versions of a **provider or module** Terraform is allowed to use. They prevent automatic upgrades to incompatible versions that might break your infrastructure.

## Provider Version Constraints
Version constraints are defined in the `terraform` block's `required_providers` section:

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "1.2.0"  # Specify version constraint here
    }
  }
}
```

## Version Constraint Operators

| Operator | Example | Meaning |
|----------|---------|---------|
| `=` | `version = "1.2.0"` | Exact version only |
| `!=` | `version = "!= 1.2.0"` | Any version except this one |
| `>` | `version = "> 1.2.0"` | Greater than this version |
| `<` | `version = "< 2.0.0"` | Less than this version |
| `>=` | `version = ">= 1.2.0"` | Greater than or equal to |
| `<=` | `version = "<= 2.0.0"` | Less than or equal to |
| `~>` | `version = "~> 1.2"` | Pessimistic constraint (see below) |

## Pessimistic Constraint Operator (~>)
The `~>` operator allows rightmost version segment to increment while freezing others.

```hcl
version = "~> 1.2"      # Allows 1.2.x, 1.3.x, etc. but NOT 2.0.0
version = "~> 1.2.3"    # Allows 1.2.3, 1.2.4, 1.2.5 but NOT 1.3.0
```

**Use when:** You want flexibility for patch/minor updates but stability for major versions.

## Combining Constraints
Multiple constraints can be combined with commas:

```hcl
version = "> 1.2.0, < 2.0.0"         # Between 1.2.0 and 2.0.0
version = ">= 1.2.0, < 2.0.0, != 1.4.0"  # Exclude specific version
```

## Real-World Examples

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"      # Use AWS provider 5.x.x (patch updates OK)
    }
    
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0, < 3.0.0"  # Support 2.x but not 3.0+
    }
    
    random = {
      source  = "hashicorp/random"
      version = "!= 3.2.0"    # Avoid buggy version 3.2.0
    }
  }
}
```

## Best Practices

- **Use `~>`** for stable production environments (allows patch updates)
- **Use `>= x.0, < y.0`** for more explicit control over major versions
- **Avoid `=` for exact versions** unless you have a specific reason (locks you out of security updates)
- **Test updates** before deploying to production when constraints allow new versions
- **Document why** specific constraints are in place (e.g., "AWS 4.x is EOL")

## Terraform Version Constraints
You can also constrain the Terraform CLI version itself:

```hcl
terraform {
  required_version = ">= 1.0, < 2.0"  # Requires Terraform 1.x
}
```

