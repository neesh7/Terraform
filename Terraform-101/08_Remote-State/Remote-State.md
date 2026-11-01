# 8. Remote State — *15:16*

| # | Topic | Duration |
|---|-------|----------|
| 1 | What is Remote State and State Locking? | 06:21 |
| 2 | Remote Backends with S3 | 03:59 |
| 3 | Lab: Remote State | — |
| 4 | Terraform State Commands | 04:56 |
| 5 | Lab: Terraform State Commands | — |

## Notes

### Understanding Terraform State Files

**What is a tfstate file?**
- JSON file that stores the current state of infrastructure managed by Terraform
- Created after first `terraform apply` execution
- Contains mapping between Terraform configuration and real-world AWS/cloud resources
- Tracks resource attributes, IDs, dependencies, and metadata
- Default location: `terraform.tfstate` in working directory (local state)

**Why tfstate files are critical:**
1. **Mapping Configuration to real-world infra** — Links logical resources in .tf files to actual cloud resources (e.g., aws_instance "web" → i-0123456789abcdef0)
2. **Tracking metadata** — Stores resource attributes like IP addresses, DNS names, security group IDs that are computed by cloud provider
3. **Performance** — Avoids querying all resources every apply; Terraform only reconciles what changed
4. **Team Collaboration** — Enables multiple team members to work on same infrastructure safely

**tfstate file structure (JSON):**
```
{
  "version": 4,
  "terraform_version": "1.x.x",
  "serial": 5,
  "lineage": "unique-id",
  "outputs": {...},
  "resources": [...]
}
```

---

### State Locking

**What is State Locking?**
- Mechanism to prevent concurrent modifications to state file
- When one team member runs `terraform apply`, the state is locked
- Other team members cannot modify state simultaneously (operation blocks or fails)
- Lock is released after apply completes

**Why State Locking matters:**
- Prevents infrastructure inconsistency (race conditions)
- Ensures only one `terraform apply` runs at a time
- Critical for team environments; much less important for solo work

**State Lock behavior:**
- Lock stored in backend system (not in .tfstate file itself)
- Different backends handle locking differently:
  - **S3 + DynamoDB** — Uses DynamoDB table to track locks
  - **Terraform Cloud/Enterprise** — Built-in state locking
  - **Local backend** — No locking (file-based, not suitable for teams)
  - **Consul, etcd, Azure Blob, Google Cloud Storage** — Each has locking support

---

### Remote Backends

**Why Remote State?**
- **Local state problems:** 
  - Only one machine has access
  - No version control history
  - Hard to share with team
  - Security risk (sensitive data in repo)
  - No disaster recovery
  
- **Remote state benefits:**
  - Centralized state accessible to team
  - State locking for concurrent operations
  - Automatic backups and versioning
  - Better security (credentials not exposed)
  - Easy to integrate with CI/CD pipelines

**Common Remote Backends:**

1. **S3 Backend (AWS)**
   - State stored in S3 bucket
   - Locking via DynamoDB table
   - Cost-effective, highly available
   - Configuration:
     ```hcl
     terraform {
       backend "s3" {
         bucket         = "my-terraform-state"
         key            = "prod/terraform.tfstate"
         region         = "us-east-1"
         encrypt        = true
         dynamodb_table = "terraform-locks"
       }
     }
     ```

2. **Terraform Cloud/Enterprise**
   - Official Terraform backend
   - Remote runs, cost estimation, policy as code
   - Free tier available

3. **Azure Blob Storage**
   - State stored in Azure Blob Storage container
   - Locking via Azure Blob Storage leases
   - Standard choice for Azure organizations
   - Configuration:
     ```hcl
     terraform {
       backend "azurerm" {
         resource_group_name  = "my-rg"
         storage_account_name = "mystateaccount"
         container_name       = "tfstate"
         key                  = "prod/terraform.tfstate"
       }
     }
     ```

4. **Google Cloud Storage, Consul, etcd**
   - Alternative backends for different cloud providers

---

### Industry Standards for Remote State

**Terraform Cloud (Official Standard)**
- Officially maintained by HashiCorp
- Built-in state locking, versioning, policy as code
- Remote runs with cost estimation
- Best for: Enterprise teams, policy enforcement, multi-cloud
- Cost: Free tier available; paid tiers for advanced features

**Cloud Provider-Native Backends (Practical Standard)**
- Most widely used in practice due to cost and control
- AWS: S3 + DynamoDB (extremely popular)
- Azure: Azure Blob Storage (standard for Azure)
- GCP: Google Cloud Storage (standard for GCP)
- Best for: Teams already invested in cloud provider, cost-conscious organizations

**When to use each:**
| Scenario | Recommended Backend |
|----------|-------------------|
| Large enterprises with policy requirements | Terraform Cloud/Enterprise |
| AWS-only organizations | S3 + DynamoDB |
| Azure-only organizations | Azure Blob Storage |
| GCP-only organizations | Google Cloud Storage |
| Multi-cloud teams | Terraform Cloud |
| Startups/cost-sensitive | Cloud provider storage |
| Solo development | Local (with Git caution) |

---

### Terraform State Commands

**Overview:**
State commands allow you to view, modify, and manage Terraform state without applying new infrastructure changes. Use these with caution—incorrect state modifications can cause Terraform to lose track of resources.

**Key state commands:**

| Command | Purpose |
|---------|---------|
| `terraform state list` | List all resources currently in state |
| `terraform state show <resource>` | Display detailed attributes of a specific resource |
| `terraform state mv <source> <dest>` | Rename/move resource in state (refactoring) |
| `terraform state rm <resource>` | Remove resource from state (stop managing it) |
| `terraform state pull` | Download current state locally |
| `terraform state push <file>` | Upload local state to remote backend |
| `terraform refresh` | Update state by querying real infrastructure |
| `terraform show` | Display current state (local or remote) |

---

#### 1. **terraform state list**
Lists all resources currently tracked in state file.

**Usage:**
```bash
terraform state list
```

**Example output:**
```
azurerm_resource_group.app
azurerm_storage_account.app
random_string.storage_suffix
```

**Filter by type:**
```bash
terraform state list | grep azurerm_storage_account
```

---

#### 2. **terraform state show**
Displays detailed attributes of a specific resource in state.

**Usage:**
```bash
terraform state show <resource_type>.<resource_name>
```

**Examples:**
```bash
# Show all attributes of a storage account
terraform state show azurerm_storage_account.app

# Output:
# resource "azurerm_storage_account" "app":
# {
#   "id": "/subscriptions/.../providers/Microsoft.Storage/storageAccounts/appsa...",
#   "name": "appsa...",
#   "location": "eastus",
#   "account_tier": "Standard",
#   "account_replication_type": "GRS",
#   ...
# }

# Show specific attribute
terraform state show azurerm_storage_account.app | grep "name ="
```

**S3 Bucket example (AWS):**
```bash
terraform state show aws_s3_bucket.finance
```

---

#### 3. **terraform state mv**
Renames or moves a resource in state without destroying and recreating it. Useful for refactoring.

**Usage:**
```bash
terraform state mv <source> <destination>
```

**Examples:**

**Rename resource:**
```bash
# Rename from "old_name" to "new_name"
terraform state mv azurerm_storage_account.old azurerm_storage_account.new

# Update your .tf files to use the new name
# resource "azurerm_storage_account" "new" { ... }
```

**Move resource between modules:**
```bash
terraform state mv aws_instance.web module.web_tier.aws_instance.web
```

**Benefits:**
- No downtime (resource not destroyed/recreated)
- Useful when refactoring code structure
- Keeps resource IDs and configurations intact

---

#### 4. **terraform state rm**
Removes a resource from state without destroying it. Use when you want to stop managing a resource with Terraform.

**Usage:**
```bash
terraform state rm <resource>
```

**Examples:**

```bash
# Stop managing a storage account (doesn't delete it in Azure)
terraform state rm azurerm_storage_account.old

# Stop managing multiple resources
terraform state rm azurerm_resource_group.old azurerm_storage_account.old

# After removal, import it back later if needed
terraform import azurerm_storage_account.new /subscriptions/.../storageAccounts/myaccount
```

**Warning:** After removal, Terraform won't track this resource. You must manually manage it or import it later.

---

#### 5. **terraform state pull**
Downloads the current state file from remote backend to local machine. Useful for inspection or backup.

**Usage:**
```bash
terraform state pull > backup.tfstate
```

**Examples:**

```bash
# Save remote state locally
terraform state pull > terraform.tfstate.backup

# View remote state contents
terraform state pull | jq '.resources[0]'

# Share state for debugging (be careful with sensitive data!)
terraform state pull > state_for_review.json
```

**Security note:** State files contain sensitive data. Handle backups carefully.

---

#### 6. **terraform state push**
Uploads local state file to remote backend. Use after restoring from backup or manual edits.

**Usage:**
```bash
terraform state push <file>
```

**Examples:**

```bash
# Restore state from backup
terraform state push backup.tfstate

# Update remote state with local version
terraform state push terraform.tfstate
```

**Warning:** This overwrites remote state. Use only when necessary (e.g., disaster recovery).

---

#### 7. **terraform refresh**
Queries actual infrastructure and updates state file without applying changes. Reconciles state with reality.

**Usage:**
```bash
terraform refresh
```

**When to use:**
- Resource modified outside Terraform (manual Azure Portal changes)
- Resource deleted or changed by another team member
- State is out of sync with real infrastructure

**Example scenario:**
```bash
# Someone manually modified storage account in Azure Portal
terraform refresh  # Updates state to reflect actual configuration
terraform plan     # Shows what changes Terraform would make
```

---

#### 8. **terraform show**
Displays the current state file contents (human-readable).

**Usage:**
```bash
terraform show              # Show full state
terraform show -json       # Show state in JSON format
terraform show -json | jq  # Pretty-print JSON
```

**Examples:**

```bash
# View entire state
terraform show

# View as JSON
terraform show -json > state.json

# Extract specific resource from JSON
terraform show -json | jq '.values.root_module.resources[] | select(.address=="azurerm_storage_account.app")'
```

---

### Common State Workflows

**Refactor resource names safely:**
```bash
# 1. Rename in state
terraform state mv azurerm_storage_account.old azurerm_storage_account.new

# 2. Update .tf files to use new name
# 3. Run plan to verify no changes
terraform plan

# 4. Apply (should show no changes)
terraform apply
```

**Backup and restore:**
```bash
# Backup
terraform state pull > backup-$(date +%Y%m%d).tfstate

# Restore if needed
terraform state push backup-20240615.tfstate
```

**Debug state issues:**
```bash
# Check if resource in state matches real infrastructure
terraform state show aws_s3_bucket.finance
aws s3api head-bucket --bucket <actual-bucket-name>

# If out of sync, refresh
terraform refresh
```

**Stop managing a resource:**
```bash
# Remove from state (doesn't delete it)
terraform state rm aws_instance.deprecated

# Later: import it back if needed
terraform import aws_instance.deprecated i-1234567890abcdef0
```

---

### Best Practices for tfstate Management

1. **Never commit .tfstate to Git**
   - Add to .gitignore: `*.tfstate`, `*.tfstate.*`
   - Contains sensitive data (passwords, keys, private IPs)

2. **Use Remote State for Teams**
   - Local state only for development/learning
   - Production must use remote backend with locking

3. **Enable State Encryption**
   - At rest: S3 encryption, Azure encryption
   - In transit: HTTPS/TLS

4. **Backup State Regularly**
   - S3 versioning enabled
   - Regular snapshots to separate location

5. **Control Access to State**
   - IAM policies to limit who can read/modify state
   - State contains sensitive information (passwords, tokens)

6. **Avoid Manual State Edits**
   - Only modify via `terraform state` commands
   - Direct JSON edits risk corruption

7. **Use State Locking**
   - Enables safe concurrent operations
   - Prevents apply conflicts in teams