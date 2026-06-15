# Terraform State Commands Reference

Quick reference guide for Terraform state management commands.

---

## State Commands Overview

| Command | Purpose | Use Case |
|---------|---------|----------|
| `terraform state list` | List all resources in state | See what's being managed |
| `terraform state show` | Show resource details | Inspect resource attributes |
| `terraform state mv` | Rename/move resource | Refactor without destroying |
| `terraform state rm` | Remove resource from state | Stop managing a resource |
| `terraform state pull` | Download state locally | Backup or inspect |
| `terraform state push` | Upload state to backend | Restore from backup |
| `terraform refresh` | Sync state with real infra | Fix out-of-sync state |
| `terraform show` | Display current state | View all resources |

---

## Command Examples

### List Resources
```bash
terraform state list
terraform state list | grep aws_s3
```

### Show Resource Details
```bash
terraform state show aws_s3_bucket.finance
terraform state show azurerm_storage_account.app
```

### Move/Rename Resource
```bash
terraform state mv aws_instance.old aws_instance.new
terraform state mv aws_instance.web module.web.aws_instance.web
```

### Remove Resource from State
```bash
terraform state rm aws_instance.old
terraform state rm aws_s3_bucket.old azurerm_storage_account.old
```

### Backup State
```bash
terraform state pull > backup.tfstate
terraform state pull > terraform.tfstate.backup.$(date +%Y%m%d)
```

### Restore State
```bash
terraform state push backup.tfstate
terraform state push terraform.tfstate.backup.20240615
```

### Sync State with Reality
```bash
terraform refresh
```

### View Full State
```bash
terraform show
terraform show -json
terraform show -json | jq
```

---

## Common Workflows

### 1. Refactor Resource Names Safely
```bash
terraform state mv aws_instance.old aws_instance.new
# Update .tf files
terraform plan    # Verify no changes
terraform apply
```

### 2. Create Regular Backups
```bash
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate
```

### 3. Stop Managing a Resource
```bash
terraform state rm aws_instance.deprecated
# Resource still exists in AWS, just not managed by Terraform
```

### 4. Debug Out-of-Sync State
```bash
terraform state show aws_s3_bucket.finance
# Compare with actual AWS console
terraform refresh  # Update state
terraform plan     # Check changes
```

### 5. Fix State Corruption
```bash
# Backup first
terraform state pull > corrupted.tfstate.bak

# Check state
terraform state list

# If needed, restore
terraform state push good-state.tfstate
```

### 6. Move Resource to Module
```bash
terraform state mv aws_instance.web module.web.aws_instance.web
```

---

## Quick Tips

⚠️ **Always backup state before modifying:**
```bash
terraform state pull > backup.tfstate
```

✅ **Verify changes after state modifications:**
```bash
terraform plan
```

🔒 **Protect sensitive state data:**
- Use remote backends with encryption
- Never commit .tfstate to Git
- Limit access to state files

❓ **Check state without modifying:**
```bash
terraform state list
terraform state show <resource>
terraform show
```

🔄 **Sync state when using manual changes:**
```bash
terraform refresh
terraform plan
```

---

## AWS Examples

```bash
# List S3 buckets
terraform state list | grep aws_s3_bucket

# Show S3 bucket details
terraform state show aws_s3_bucket.finance

# Move EC2 instance
terraform state mv aws_instance.web aws_instance.web_server

# Remove auto-scaling group
terraform state rm aws_autoscaling_group.old
```

---

## Azure Examples

```bash
# List storage accounts
terraform state list | grep azurerm_storage_account

# Show resource group details
terraform state show azurerm_resource_group.app

# Move storage account
terraform state mv azurerm_storage_account.old azurerm_storage_account.new

# Remove VM
terraform state rm azurerm_virtual_machine.old
```

---

## State File Safety

| Action | Command | Risk |
|--------|---------|------|
| View state | `terraform show` | None |
| List resources | `terraform state list` | None |
| Check resource | `terraform state show` | None |
| Rename resource | `terraform state mv` | Medium — Test with plan |
| Remove resource | `terraform state rm` | High — Resource orphaned |
| Upload state | `terraform state push` | High — Overwrites remote |
| Refresh state | `terraform refresh` | Low — Read-only |

---

## Important Notes

- ⚠️ State modifications bypass normal Terraform validation
- ✅ Always run `terraform plan` after state changes
- 🔒 State contains sensitive data (passwords, API keys)
- 💾 Regularly backup state files
- 🚫 Never edit state JSON directly
- 🔄 Use `terraform refresh` to sync with real infrastructure
