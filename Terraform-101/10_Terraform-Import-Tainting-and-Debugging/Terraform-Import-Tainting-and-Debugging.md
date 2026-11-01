# 10. Terraform Import, Tainting Resources and Debugging — *8:26*

| # | Topic | Duration |
|---|-------|----------|
| 1 | Terraform Taint | 01:57 |
| 2 | Debugging | 01:43 |
| 3 | Lab: Taint and Debugging | — |
| 4 | Terraform Import | 04:46 |
| 5 | Lab: Terraform Import | — |
| 6 | Feedback: How do you like the course so far? | — |

## Notes

### 1. Terraform Taint Command

#### What is Taint?
- Marks a specific resource instance as "tainted" in the Terraform state
- Tainted resources are marked for destruction and recreation on the next `terraform apply`
- Does NOT immediately destroy the resource — it only marks it in state
- Forces Terraform to replace the resource instead of updating it

#### Syntax
```bash
terraform taint [options] address
```

**Example:**
```bash
terraform taint aws_instance.web_server
terraform taint 'aws_instance.example[0]'
terraform taint aws_security_group.main
```

#### How It Works
1. Modifies the resource in the state file, adding a `tainted` flag
2. Next `terraform plan` will show the resource for destruction and recreation
3. `terraform apply` will destroy the old resource and create a new one
4. The resource definition in `.tf` files remains unchanged

#### Common Options
```bash
terraform taint -allow-missing address      # Don't error if resource doesn't exist
```

#### Use Cases

**1. Force Replacement for Configuration Drift**
- Resource was manually modified outside Terraform
- You want Terraform to restore it to the defined state
```bash
# EC2 instance was manually modified in AWS console
terraform taint aws_instance.app
terraform apply  # Destroys old and creates new instance
```

**2. Resolve Configuration Changes**
- Made a breaking change to a resource that requires replacement
- Example: changing EBS volume type requires replacement
```bash
# In .tf file: changed volume_type = "gp2" to volume_type = "io1"
terraform taint aws_ebs_volume.data
terraform apply  # Recreates with new volume type
```

**3. Fix Corrupted or Misconfigured Resources**
- Resource is in an inconsistent state
- Easier to recreate than manually fix
```bash
terraform taint aws_rds_instance.database
terraform apply  # Fresh database instance
```

**4. Update Immutable Attributes**
- Some attributes cannot be updated in-place
- Tainting forces replacement instead of error
```bash
terraform taint aws_elasticache_cluster.cache
terraform apply  # Recreates with updated immutable properties
```

**5. Testing Disaster Recovery**
- Simulate resource failure and recovery
- Verify failover mechanisms work correctly
```bash
terraform taint aws_instance.primary
terraform apply  # Tests if backup systems activate
```

---

### 2. Terraform Untaint Command

#### What is Untaint?
- Removes the "tainted" flag from a resource in the state
- Cancels the planned destruction and recreation
- Useful if you marked a resource for tainting by mistake
- Returns the resource to normal management state

#### Syntax
```bash
terraform untaint [options] address
```

**Example:**
```bash
terraform untaint aws_instance.web_server
terraform untaint aws_rds_instance.prod_db
```

#### How It Works
1. Removes the tainted flag from the state file
2. Resource will NOT be destroyed on next `terraform apply`
3. Returns to normal state management
4. Useful for undoing an accidental `taint` command

#### Common Options
```bash
terraform untaint -allow-missing address   # Don't error if resource doesn't exist
```

#### Use Cases

**1. Undo Accidental Taint**
- Marked a resource for tainting by mistake
- Quickly recover without making changes
```bash
terraform taint aws_instance.prod  # Oops, wrong instance!
terraform untaint aws_instance.prod  # Cancel the taint
```

**2. Conditional Replacement**
- Reviewed the plan and decided NOT to replace the resource
- Untaint before applying changes
```bash
terraform plan  # Shows resource will be replaced
# Review impact and decide replacement is unnecessary
terraform untaint aws_db_instance.main
terraform apply  # Resource is updated normally, not replaced
```

**3. Manual Fix Alternative**
- Resource was tainted but then manually fixed outside Terraform
- Untaint to reflect the actual state
```bash
# Resource was tainted but manually corrected in AWS console
terraform untaint aws_security_group.firewall
# Continue managing it normally via Terraform
```

---

### 3. Taint vs Update Workflow

| Scenario | Approach | Why |
|----------|----------|-----|
| Need to fix configuration drift | `taint` → `apply` | Forces complete recreation |
| Need to change immutable attribute | `taint` → `apply` | Avoids error, creates new resource |
| Made a mistake tainting | `untaint` | Quickly cancel without side effects |
| Attribute can be updated in-place | Just modify `.tf` | Faster, no downtime |
| Need to test replacement | `taint` → `plan` → review → `apply` | Verify impact before committing |

---

### 4. Practical Workflow Example

**Scenario:** Database needs to change from single-AZ to multi-AZ (immutable attribute)

```bash
# Step 1: Edit the terraform configuration
# Change: availability_zones = ["us-east-1a"]
# To: availability_zones = ["us-east-1a", "us-east-1b"]

# Step 2: Check what would happen
terraform plan
# Output shows UPDATE (but may fail due to immutable attribute)

# Step 3: Mark for replacement instead
terraform taint aws_rds_cluster_instance.primary

# Step 4: Review the plan
terraform plan
# Now shows DESTROY + CREATE instead of UPDATE

# Step 5: Apply the change (resource is destroyed and recreated)
terraform apply

# Step 6: Verify the new configuration
aws rds describe-db-clusters  # Confirm multi-AZ setup
```

---

### 5. State File Impact

#### Before Taint
```json
{
  "resources": [{
    "type": "aws_instance",
    "instances": [{
      "attributes": {"id": "i-0123456789abcdef"}
    }]
  }]
}
```

#### After Taint
```json
{
  "resources": [{
    "type": "aws_instance",
    "instances": [{
      "attributes": {"id": "i-0123456789abcdef"},
      "status": "tainted"  // Marked for replacement
    }]
  }]
}
```

#### After Untaint
```json
{
  "resources": [{
    "type": "aws_instance",
    "instances": [{
      "attributes": {"id": "i-0123456789abcdef"}
      // Status removed - back to normal
    }]
  }]
}
```

---

### 6. Best Practices

✅ **Do:**
- Use `terraform plan` before `terraform apply` after tainting
- Document why a resource was tainted in version control/comments
- Consider the impact of replacing production resources
- Test taint/untaint in non-production environments first
- Use taint to force replacement of corrupted/drifted resources

❌ **Don't:**
- Taint critical production resources without proper planning
- Forget to verify the replacement succeeded
- Use taint as a substitute for fixing configuration issues
- Leave resources tainted indefinitely — apply changes promptly
- Taint resources that are actively serving traffic without preparation

---

### 7. Terraform Debugging with Logs

#### Overview
Terraform provides detailed logging capabilities to troubleshoot issues and understand what's happening during operations. Logs help identify configuration errors, API call problems, and state management issues.

#### Log Levels
Terraform supports five log levels (from least to most verbose):

| Level | Description | Use Case |
|-------|-------------|----------|
| `error` | Only errors | Production troubleshooting |
| `warning` | Warnings and errors | Identify non-critical issues |
| `info` | General information | Normal debugging |
| `debug` | Detailed debugging information | Development troubleshooting |
| `trace` | Very detailed trace logs | Deep investigation, API debugging |

---

#### Enabling Logging with TF_LOG

##### Set Log Level
```bash
export TF_LOG=TRACE
terraform plan
terraform apply
```

**Other levels:**
```bash
export TF_LOG=DEBUG
export TF_LOG=INFO
export TF_LOG=WARNING
export TF_LOG=ERROR
```

##### Example: Debugging with TRACE Level
```bash
export TF_LOG=TRACE
terraform init
# Outputs detailed logs for initialization process
```

---

#### Saving Logs to a File with TF_LOG_PATH

##### Set Log Output Path
```bash
export TF_LOG_PATH=/tmp/terraform.log
export TF_LOG=TRACE
terraform apply
```

This creates a log file at `/tmp/terraform.log` with all debug output.

##### View First 10 Lines
```bash
head -10 /tmp/terraform.log
```

##### View Last 20 Lines
```bash
tail -20 /tmp/terraform.log
```

##### Search for Errors in Logs
```bash
grep -i "error" /tmp/terraform.log
grep -i "failed" /tmp/terraform.log
```

##### View Entire Log File
```bash
cat /tmp/terraform.log
```

---

#### Disabling Logging

##### Unset Log Path
```bash
unset TF_LOG_PATH
unset TF_LOG
```

Or explicitly disable:
```bash
export TF_LOG=""
```

---

#### Practical Debugging Workflow

**Scenario:** API authentication is failing during `terraform apply`

```bash
# Step 1: Enable trace-level logging
export TF_LOG=TRACE
export TF_LOG_PATH=./terraform-debug.log

# Step 2: Run the failing command
terraform apply

# Step 3: Search for the specific error
grep -i "authentication\|unauthorized\|403" terraform-debug.log

# Step 4: Review context around the error
grep -B 5 -A 10 "authentication" terraform-debug.log

# Step 5: Identify the root cause (e.g., invalid credentials, expired token)

# Step 6: Fix the issue (update credentials, refresh token, etc.)

# Step 7: Disable logging for production
unset TF_LOG
unset TF_LOG_PATH

# Step 8: Run again with normal operation
terraform apply
```

---

#### Log Output Examples

##### Example 1: TRACE Level Output
```
2026-06-17T10:15:23.456Z [TRACE] provider.aws: Calling AWS API
2026-06-17T10:15:23.457Z [DEBUG] aws_instance.web: Creating instance
2026-06-17T10:15:23.458Z [INFO] AWS API responded with instance ID
2026-06-17T10:15:24.120Z [TRACE] State updated successfully
```

##### Example 2: Error in Logs
```
2026-06-17T10:15:25.789Z [ERROR] Failed to create security group
2026-06-17T10:15:25.790Z [ERROR] InvalidGroup.Duplicate error on line 42
2026-06-17T10:15:25.791Z [WARN] Rolling back changes
```

---

#### Common Debugging Scenarios

**1. Provider Authentication Issues**
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./provider-debug.log
terraform init
grep -i "credentials\|auth" provider-debug.log
```

**2. State File Problems**
```bash
export TF_LOG=TRACE
terraform state list
terraform state show aws_instance.web
# Logs show state operations and potential inconsistencies
```

**3. Resource Creation Failures**
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./resource-debug.log
terraform apply -target=aws_instance.web
# Logs show API calls and responses
```

**4. Configuration Parsing Errors**
```bash
export TF_LOG=INFO
terraform validate
# Logs show configuration evaluation and validation details
```

**5. Dependency Resolution Issues**
```bash
export TF_LOG=DEBUG
terraform graph > graph.dot
# Logs show dependency calculation and order
```

---

#### Log File Management

**Tips for Log Files:**

| Task | Command |
|------|---------|
| Monitor logs in real-time | `tail -f /tmp/terraform.log` |
| Search for warnings | `grep -i "WARN" /tmp/terraform.log` |
| Get log file size | `du -h /tmp/terraform.log` |
| Clear old logs | `rm /tmp/terraform.log` |
| Archive logs | `gzip /tmp/terraform.log` |
| Count errors | `grep -i "ERROR" /tmp/terraform.log \| wc -l` |

---

#### Best Practices for Debugging

✅ **Do:**
- Use `DEBUG` or `INFO` level for most troubleshooting
- Use `TRACE` only when you need very detailed information
- Save logs to a file for review and analysis
- Include relevant log excerpts in documentation/tickets
- Use grep to filter logs for specific issues
- Keep logs organized with meaningful file names
- Clean up old logs to save disk space

❌ **Don't:**
- Leave `TF_LOG=TRACE` enabled in production (performance impact)
- Commit logs with sensitive data (credentials, tokens) to version control
- Ignore warnings in logs — they often indicate problems
- Use TRACE level for routine operations (generates huge logs)
- Leave TF_LOG_PATH set permanently (disk space issues)

---

#### Windows PowerShell Logging

For PowerShell on Windows:

```powershell
# Set environment variable
$env:TF_LOG = "TRACE"
$env:TF_LOG_PATH = "C:\Temp\terraform.log"

terraform apply

# View logs
Get-Content C:\Temp\terraform.log -Head 20

# Unset variables
$env:TF_LOG = ""
$env:TF_LOG_PATH = ""
```

---

#### Linux/macOS Logging

For Bash/Zsh on Linux/macOS:

```bash
# Set environment variables
export TF_LOG=TRACE
export TF_LOG_PATH=/tmp/terraform.log

terraform apply

# View logs
head -50 /tmp/terraform.log

# Unset variables
unset TF_LOG
unset TF_LOG_PATH
```

---

### 8. Terraform Import

#### Overview
`terraform import` brings existing infrastructure into Terraform state management. Useful when you have resources created outside Terraform or need to migrate existing infrastructure under Terraform control.

#### What Import Does
- Reads an existing resource from your cloud provider
- Creates a state file entry for that resource
- Imports the resource as-is WITHOUT running `terraform apply`
- Does NOT create the resource definition file (`.tf`) — you must write it manually
- Establishes the relationship between `.tf` code and existing infrastructure

#### Syntax
```bash
terraform import <resource_type>.<resource_name> <unique_attribute>
```

**Parameters:**
- `resource_type`: AWS/Azure/GCP resource type (e.g., `aws_instance`, `aws_s3_bucket`)
- `resource_name`: Name in your Terraform code (can be anything)
- `unique_attribute`: Resource ID from your cloud provider (varies by resource type)

#### Common Unique Attributes by Resource Type

| Resource Type | Unique Attribute |
|---------------|------------------|
| `aws_instance` | Instance ID (i-0123456789) |
| `aws_s3_bucket` | Bucket name |
| `aws_security_group` | Security group ID (sg-0123) |
| `aws_vpc` | VPC ID (vpc-0123) |
| `aws_subnet` | Subnet ID (subnet-0123) |
| `aws_rds_instance` | Database instance identifier |
| `aws_iam_role` | Role name |
| `aws_iam_user` | Username |
| `aws_elb` | Load balancer name |
| `aws_key_pair` | Key pair name |

---

#### Import Syntax Examples

```bash
# EC2 Instance
terraform import aws_instance.web i-0123456789abcdef0

# S3 Bucket
terraform import aws_s3_bucket.my_bucket my-bucket-name

# Security Group
terraform import aws_security_group.main sg-0123456789abcdef0

# RDS Instance
terraform import aws_db_instance.database mydb-instance

# VPC
terraform import aws_vpc.main vpc-0123456789abcdef0

# IAM Role
terraform import aws_iam_role.app_role app-role-name
```

---

#### Step-by-Step Import Workflow

**Scenario:** You have an EC2 instance running but not managed by Terraform

```bash
# Step 1: Find the instance ID in AWS Console
# Instance ID: i-0a1b2c3d4e5f6g7h8

# Step 2: Create the Terraform resource definition (skeleton)
# File: main.tf
resource "aws_instance" "app_server" {
  # Configuration will be filled after import
}

# Step 3: Run import command
terraform import aws_instance.app_server i-0a1b2c3d4e5f6g7h8
# Output: Successfully imported! Resource added to state

# Step 4: View the imported resource in state
terraform state show aws_instance.app_server
# Outputs all current attributes

# Step 5: Copy the attributes from state into your .tf file
# terraform state show outputs something like:
# resource "aws_instance" "app_server" {
#   ami = "ami-0123456789"
#   instance_type = "t2.micro"
#   ...
# }

# Step 6: Update your main.tf with the resource configuration
resource "aws_instance" "app_server" {
  ami           = "ami-0123456789"
  instance_type = "t2.micro"
  tags = {
    Name = "app-server"
  }
}

# Step 7: Verify the import is correct
terraform plan
# Should show: No changes. Your infrastructure matches the configuration.

# Step 8: Now manage the resource normally
# Any further changes go through terraform apply
```

---

#### Import Use Cases

**1. Migrate Existing Infrastructure to Terraform**
- Infrastructure exists but isn't managed by Terraform
- Bring it under Terraform control for consistent management
```bash
# Your AWS has 10 running EC2 instances created manually
# Import each one to manage via Terraform
terraform import aws_instance.web1 i-111111
terraform import aws_instance.web2 i-222222
terraform import aws_instance.db1 i-333333
```

**2. Consolidate Multi-Team Infrastructure**
- Different teams manage resources in AWS
- Centralize under single Terraform configuration
```bash
terraform import aws_s3_bucket.marketing marketing-bucket
terraform import aws_s3_bucket.analytics analytics-bucket
```

**3. Adopt Infrastructure from Manual Deployment**
- Infrastructure was deployed via CloudFormation or manual clicks
- Switch to Terraform management
```bash
terraform import aws_rds_instance.prod prod-database-instance
```

**4. Recover Accidentally Deleted State File**
- State file was lost but infrastructure still exists
- Re-import resources to restore state
```bash
terraform import aws_vpc.main vpc-abc123
terraform import aws_subnet.web subnet-xyz789
```

**5. Share Infrastructure Across Teams**
- One team created resources, another team needs to manage them
- Import into the managing team's Terraform configuration
```bash
terraform import aws_iam_role.shared shared-app-role
```

---

#### Import Workflow with State File Locations

```bash
# Check current state before import
terraform state list
# (no resources)

# Run import
terraform import aws_instance.example i-0123456789

# Verify resource was added to state
terraform state list
# Output: aws_instance.example

# View details
terraform state show aws_instance.example
```

---

#### Key Points About Import

✅ **What import does:**
- Adds resource to Terraform state
- Establishes association with actual cloud resource
- Allows Terraform to manage future changes

❌ **What import does NOT do:**
- Does NOT create the `.tf` file — you must write it
- Does NOT read resource attributes into your code — you must copy them
- Does NOT remove the resource from your cloud provider
- Does NOT validate that `.tf` code matches actual resource

---

#### Common Import Issues

**Issue 1: Wrong Resource ID**
```bash
terraform import aws_instance.web i-wrong-id
# Error: Resource not found
# Solution: Verify the instance ID from AWS Console
```

**Issue 2: Resource Already in State**
```bash
terraform import aws_instance.web i-0123456789
# Error: Resource already exists in state
# Solution: Use different resource name or remove from state first
terraform state rm aws_instance.web  # Remove first
```

**Issue 3: Resource Definition Missing**
```bash
terraform import aws_instance.web i-0123456789
# Works, but you must add resource block to main.tf
# Or terraform plan will try to create it
```

---

#### Best Practices for Import

✅ **Do:**
- Plan imports carefully — document which resources to import
- Import one resource at a time, verify, then move to next
- Copy imported attributes into `.tf` files immediately
- Run `terraform plan` after import to verify state matches code
- Test imports in non-production environments first
- Keep imported resources in version control
- Document the import process for future reference

❌ **Don't:**
- Import resources without creating the corresponding `.tf` definitions
- Forget to run `terraform plan` after import
- Import critical production resources without testing
- Mix manual changes with Terraform management
- Assume imported state matches your desired `.tf` configuration
- Leave resources in state without `.tf` definitions (creates drift)

---

#### Import vs Manual Management

| Approach | Pros | Cons |
|----------|------|------|
| **Import existing** | Brings unmanaged resources under control, captures current state | Requires manual `.tf` code writing, state may not match desired config |
| **Define & Create** | Fully controlled via code from start, reproducible | Requires creating resources from scratch, downtime possible |
| **Manual (no import)** | Quick one-off changes | Infrastructure drift, hard to track, not reproducible |

---

#### Complete Import Example: Importing VPC and Subnets

```bash
# Scenario: VPC and subnets exist in AWS, need to manage via Terraform

# Step 1: Get IDs from AWS Console
# VPC ID: vpc-12345678
# Subnet 1 ID: subnet-87654321
# Subnet 2 ID: subnet-11111111

# Step 2: Create resource definitions (minimal)
# main.tf
resource "aws_vpc" "main" {}
resource "aws_subnet" "web" {}
resource "aws_subnet" "db" {}

# Step 3: Import each resource
terraform import aws_vpc.main vpc-12345678
terraform import aws_subnet.web subnet-87654321
terraform import aws_subnet.db subnet-11111111

# Step 4: View imported state
terraform state show aws_vpc.main
terraform state show aws_subnet.web
terraform state show aws_subnet.db

# Step 5: Update main.tf with actual configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "web" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

# Step 6: Verify everything matches
terraform plan
# Output: No changes needed

# Step 7: Now you can manage these via Terraform
terraform apply
```
