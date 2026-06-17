# Terraform Taint, Untaint & Debugging — Quick Reference

## Terraform Taint
Marks resource for destruction and recreation (not immediate deletion).

```bash
terraform taint aws_instance.web
terraform taint 'aws_instance.example[0]'
terraform plan       # Shows DESTROY + CREATE
terraform apply      # Replaces the resource
```

**Use Cases:**
- Force replace corrupted/drifted resources
- Replace resources with immutable attribute changes
- Fix configuration inconsistencies
- Test disaster recovery

**Options:**
```bash
terraform taint -allow-missing address    # Don't error if missing
```

---

## Terraform Untaint
Removes taint flag, cancels planned replacement.

```bash
terraform untaint aws_instance.web
terraform plan       # Resource no longer marked for replacement
terraform apply      # Normal update, not replacement
```

**Use Cases:**
- Undo accidental taint
- Cancel replacement after reviewing plan
- Fix manually corrected resources

---

## When to Use What
| Scenario | Action |
|----------|--------|
| Immutable attribute change | Taint → Apply |
| Configuration drift | Taint → Apply |
| Accidental taint | Untaint |
| In-place attribute update | Edit `.tf` → Apply |

---

## Terraform Debugging with Logs

### Enable Logging
```bash
export TF_LOG=TRACE        # Log levels: error, warning, info, debug, trace
export TF_LOG_PATH=/tmp/terraform.log
terraform plan
terraform apply
```

### View Logs
```bash
head -10 /tmp/terraform.log     # First 10 lines
tail -20 /tmp/terraform.log     # Last 20 lines
grep -i "error" /tmp/terraform.log
grep -B 5 -A 10 "failed" /tmp/terraform.log
cat /tmp/terraform.log
```

### Disable Logging
```bash
unset TF_LOG
unset TF_LOG_PATH
```

---

## Log Levels
| Level | Use Case |
|-------|----------|
| `error` | Production issues only |
| `warning` | Warnings + errors |
| `info` | General debugging |
| `debug` | Detailed troubleshooting |
| `trace` | Very detailed API calls |

---

## Common Debugging Scenarios

**Provider Auth Issues:**
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./auth-debug.log
terraform init
grep -i "credentials\|auth" auth-debug.log
```

**Resource Creation Failures:**
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./resource-debug.log
terraform apply -target=aws_instance.web
grep -i "error\|failed" resource-debug.log
```

**State Issues:**
```bash
export TF_LOG=TRACE
terraform state list
terraform state show aws_instance.web
```

---

## Best Practices

✅ **Do:**
- Use `DEBUG` or `INFO` for most troubleshooting
- Use `TRACE` only for deep investigation
- Save logs to file for analysis
- Use grep to filter logs
- Review plan before applying taint

❌ **Don't:**
- Leave TRACE enabled in production
- Commit logs with credentials
- Taint production resources without review
- Leave TF_LOG_PATH set permanently

---

## Platform-Specific

**Windows PowerShell:**
```powershell
$env:TF_LOG = "DEBUG"
$env:TF_LOG_PATH = "C:\Temp\terraform.log"
terraform apply
Get-Content C:\Temp\terraform.log -Head 20
```

**Linux/macOS:**
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=/tmp/terraform.log
terraform apply
head -20 /tmp/terraform.log
```

---

## Terraform Import
Brings existing infrastructure into Terraform state management.

```bash
terraform import <resource_type>.<resource_name> <unique_attribute>
```

**Examples:**
```bash
terraform import aws_instance.web i-0123456789abcdef0
terraform import aws_s3_bucket.my_bucket my-bucket-name
terraform import aws_security_group.main sg-0123456789
terraform import aws_rds_instance.db mydb-instance
terraform import aws_vpc.main vpc-0123456789
terraform import aws_iam_role.app app-role-name
```

**Common Unique Attributes:**
| Resource | Attribute |
|----------|-----------|
| aws_instance | Instance ID (i-...) |
| aws_s3_bucket | Bucket name |
| aws_security_group | Group ID (sg-...) |
| aws_vpc | VPC ID (vpc-...) |
| aws_subnet | Subnet ID (subnet-...) |
| aws_rds_instance | Instance identifier |
| aws_iam_role | Role name |

---

## Import Workflow
1. Find resource ID from cloud provider
2. Create resource definition in `.tf` (minimal)
3. Run `terraform import` to add to state
4. Copy attributes from `terraform state show` into `.tf`
5. Run `terraform plan` to verify match
6. Manage via Terraform going forward

**Example:**
```bash
# Find instance ID: i-0a1b2c3d4e5f6g7h8
# Create main.tf with resource "aws_instance" "web" {}
terraform import aws_instance.web i-0a1b2c3d4e5f6g7h8
terraform state show aws_instance.web  # Copy output
# Update main.tf with actual config
terraform plan  # Should show no changes
```

**Use Cases:**
- Migrate existing unmanaged infrastructure to Terraform
- Consolidate multi-team infrastructure
- Recover from deleted state file
- Adopt infrastructure from CloudFormation/manual deployment

**Important:**
- Import does NOT create `.tf` file — write it yourself
- Import does NOT create resource — just manages existing one
- Always verify with `terraform plan` after import
