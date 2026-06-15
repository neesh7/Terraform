# 7. Terraform with AWS — *59:34*

| # | Topic | Duration |
|---|-------|----------|
| 1 | Getting Started with AWS | 02:43 |
| 2 | Demo: Setup an AWS Account | 03:48 |
| 3 | Introduction to IAM | 09:17 |
| 4 | Demo: IAM | 09:54 |
| 5 | Programmatic Access | 05:34 |
| 6 | Lab: AWS CLI and IAM | — |
| 7 | AWS IAM with Terraform | 04:28 |
| 8 | IAM Policies with Terraform | 04:44 |
| 9 | Lab: IAM with Terraform | — |
| 10 | Introduction to AWS S3 | 04:54 |
| 11 | S3 with Terraform | 04:27 |
| 12 | Lab: S3 | — |
| 13 | Introduction to DynamoDB | 03:10 |
| 14 | Demo: DynamoDB | 03:29 |
| 15 | DynamoDB with Terraform | 03:06 |
| 16 | Lab: DynamoDB | — |
| 17 | Feedback: How do you like the course so far? | — |

## Notes

# AWS Resource Structure in Terraform

## Resource Syntax Overview

Every Terraform AWS resource follows this structure:

```hcl
resource "aws_iam_user" "admin-user" {
  name = "lucy"
  tags = {
    Description = "Technical Team Leader"
  }
}
```

## Components Breakdown

### 1. Block Name: `resource`
The keyword that declares you're creating an AWS resource (as opposed to `data` for data sources).

### 2. Resource Type: `aws_iam_user`
The AWS service and resource you're creating in the format: `aws_<service>_<resource>`

**Examples:**
- `aws_iam_user` — IAM User
- `aws_iam_policy` — IAM Policy
- `aws_s3_bucket` — S3 Bucket
- `aws_dynamodb_table` — DynamoDB Table
- `aws_instance` — EC2 Instance
- `aws_security_group` — Security Group

### 3. Resource Name: `admin-user`
Your local name for this resource (used to reference it in Terraform code). Must be unique within the same resource type.

**Reference syntax:** `aws_iam_user.admin-user.id`

### 4. Arguments
Configuration parameters specific to the resource type.

**Common arguments for all AWS resources:**
- `name` — Name of the resource in AWS
- `tags` — Key-value metadata for the resource
- `description` — Description of the resource purpose

**Resource-specific arguments:**
- For `aws_iam_user`: `path`, `permissions_boundary`, `force_destroy`
- For `s3_bucket`: `bucket`, `acl`, `versioning`
- For `dynamodb_table`: `name`, `billing_mode`, `attribute`

## Complete Example: IAM User with Tags

```hcl
resource "aws_iam_user" "admin-user" {
  name = "lucy"
  
  tags = {
    Description = "Technical Team Leader"
    Environment = "Production"
    Owner       = "Platform Team"
  }
}

# Reference the created resource
output "iam_user_arn" {
  value = aws_iam_user.admin-user.arn
}

output "iam_user_id" {
  value = aws_iam_user.admin-user.id
}
```

## Naming Conventions

| Component | Convention | Example |
|-----------|-----------|---------|
| **Block Name** | Lowercase (fixed) | `resource` |
| **Resource Type** | `aws_<service>_<resource>` | `aws_iam_user`, `aws_s3_bucket` |
| **Resource Name** | snake_case or kebab-case | `admin_user`, `web-server` |

## Resource Attributes and Outputs

After creating a resource, you can reference its attributes:

```hcl
resource "aws_iam_user" "lucy" {
  name = "lucy"
}

# Access attributes created by AWS
output "user_arn" {
  value = aws_iam_user.lucy.arn  # Amazon Resource Name
}

output "user_unique_id" {
  value = aws_iam_user.lucy.unique_id
}
```

## Tags in AWS Resources

Tags are key-value pairs that help organize and identify AWS resources:

```hcl
resource "aws_iam_user" "developer" {
  name = "john-dev"
  
  tags = {
    Environment = "Development"
    Project     = "WebApp"
    CostCenter  = "Engineering"
    Owner       = "DevOps Team"
  }
}
```

**Benefits of tagging:**
- Cost allocation and billing tracking
- Resource organization and filtering
- Automation and policy enforcement
- Compliance and governance

---

# AWS Credentials Configuration

For Terraform to communicate with AWS and create resources, it needs valid AWS credentials.

## Where to Store AWS Credentials

### 1. AWS Credentials File (Recommended)
The standard location for AWS credentials is the `~/.aws/credentials` file (or `%USERPROFILE%\.aws\credentials` on Windows).

**File location:**
- **Linux/Mac:** `~/.aws/credentials`
- **Windows:** `C:\Users\<YourUsername>\.aws\credentials`

**File format:**
```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY

[staging]
aws_access_key_id = STAGING_ACCESS_KEY_ID
aws_secret_access_key = STAGING_SECRET_ACCESS_KEY
```

### 2. Environment Variables
Set AWS credentials as environment variables in your shell/terminal.

**Linux/Mac:**
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**Windows PowerShell:**
```powershell
$env:AWS_ACCESS_KEY_ID = "your-access-key-id"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-access-key"
$env:AWS_DEFAULT_REGION = "us-east-1"
```

### 3. IAM Roles (For EC2 & Lambda)
If running Terraform from an EC2 instance or Lambda function, use IAM roles instead of storing credentials.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  # AWS SDK automatically uses the EC2 instance role
}
```

## Setting Up AWS Credentials

### Step 1: Create an IAM User with Programmatic Access
1. Go to AWS Console → IAM → Users
2. Create a new user (e.g., `terraform-user`)
3. Attach policies (e.g., `AdministratorAccess` for testing, more restrictive for production)
4. Enable "Programmatic Access"
5. Generate **Access Key ID** and **Secret Access Key**

### Step 2: Store the Credentials
Create the `~/.aws/credentials` file:

```bash
# Create the .aws directory if it doesn't exist
mkdir -p ~/.aws

# Create credentials file
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = AKIA1234567890ABCDEF
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY
EOF
```

### Step 3: Configure Region (Optional)
Create `~/.aws/config` file:

```ini
[default]
region = us-east-1
output = json
```

## Using Credentials in Terraform

### Default Profile
```hcl
provider "aws" {
  region = "us-east-1"
  # Uses [default] profile from credentials file
}
```

### Named Profile
```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "staging"  # Uses [staging] profile from credentials file
}
```

### Environment Variables
```hcl
provider "aws" {
  region = var.aws_region
  # Uses AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
}
```

## Security Best Practices

⚠️ **Critical Security Warnings:**

1. **Never commit credentials to Git**
   - Add `.aws/credentials` to `.gitignore`
   - Use `.gitignore` to exclude Terraform state files containing secrets

2. **Use IAM Roles instead of long-term credentials**
   - Safer for production environments
   - Automatic credential rotation

3. **Restrict IAM User Permissions**
   - Use principle of least privilege
   - Don't use AdministratorAccess in production
   - Create specific policies for Terraform

4. **Rotate Credentials Regularly**
   - Delete old access keys
   - Generate new ones periodically

5. **Use AWS Secrets Manager or Parameter Store**
   - For sensitive data like database passwords
   - Reference them in Terraform code

## Verify Credentials are Working

```bash
# Test AWS CLI connection
aws sts get-caller-identity

# Output should show your AWS account and user information
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-user"
}
```

If this works, Terraform can also access AWS with the same credentials.

---

# IAM Users, Policies, and Attachments

## Complete IAM Setup Workflow

Creating an IAM user with permissions in Terraform involves three resources:

### 1. Create IAM User
```hcl
resource "aws_iam_user" "admin-user" {
  name = "lucy"
  
  tags = {
    Description = "Technical Team Leader"
  }
}
```

### 2. Create IAM Policy
```hcl
resource "aws_iam_policy" "adminUser" {
  name   = "AdminUsers"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
}
```

### 3. Attach Policy to User
```hcl
resource "aws_iam_user_policy_attachment" "lucy-admin-access" {
  user       = aws_iam_user.admin-user.name
  policy_arn = aws_iam_policy.adminUser.arn
}
```

## Understanding Heredoc Syntax (<<EOF)

The `<<EOF` syntax allows you to write multi-line strings in Terraform, commonly used for JSON policies.

**Syntax:**
```hcl
variable_name = <<DELIMITER
Line1
Line2
Line3
DELIMITER
```

**Example:**
```hcl
policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
```

**Key points:**
- `<<EOF` starts the multi-line string
- `EOF` must be on its own line to end the string
- Everything between is treated as literal text (perfect for JSON)
- Other common delimiters: `<<EOT`, `<<POLICY`, `<<JSON`

## Alternative: Reference External Policy File

Instead of inline heredoc, you can store policies in external `.json` files and reference them using the `file()` function. This is cleaner for large/complex policies.

### File Structure
```
project/
├── main.tf
├── variables.tf
└── policies/
    ├── admin_policy.json
    ├── s3_policy.json
    └── dynamodb_policy.json
```

### Create Policy File: `policies/admin_policy.json`
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
```

### Reference in main.tf
```hcl
resource "aws_iam_policy" "adminUser" {
  name   = "AdminUsers"
  policy = file("${path.module}/policies/admin_policy.json")
}
```

### Using `file()` Function

**Syntax:**
```hcl
policy = file("path/to/policy.json")
```

**Key components:**
- `file()` — Terraform function to read file contents
- `${path.module}` — Current module directory path (makes paths relative)
- Supports `.json`, `.txt`, and other text formats

### Complete Example with External Files

**Directory structure:**
```
├── main.tf
├── variables.tf
└── policies/
    ├── admin.json
    ├── s3_read_only.json
    └── dynamodb_full.json
```

**policies/admin.json:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
```

**policies/s3_read_only.json:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::mybucket",
        "arn:aws:s3:::mybucket/*"
      ]
    }
  ]
}
```

**main.tf:**
```hcl
resource "aws_iam_user" "admin" {
  name = "admin-user"
}

resource "aws_iam_policy" "admin_policy" {
  name   = "AdminPolicy"
  policy = file("${path.module}/policies/admin.json")
}

resource "aws_iam_user_policy_attachment" "admin_access" {
  user       = aws_iam_user.admin.name
  policy_arn = aws_iam_policy.admin_policy.arn
}

# Another user with different policy
resource "aws_iam_user" "developer" {
  name = "dev-user"
}

resource "aws_iam_policy" "s3_policy" {
  name   = "S3ReadOnlyPolicy"
  policy = file("${path.module}/policies/s3_read_only.json")
}

resource "aws_iam_user_policy_attachment" "dev_s3_access" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.s3_policy.arn
}
```

## Heredoc vs File() - Comparison

| Aspect | Heredoc (<<EOF) | file() Function |
|--------|-----------------|-----------------|
| **Inline policies** | ✓ Good for small, simple policies | ✗ Not ideal |
| **Large policies** | ✗ Clutters code | ✓ Cleaner, more readable |
| **File management** | ✗ Policies mixed with code | ✓ Organized in separate files |
| **Reusability** | ✗ Have to copy-paste | ✓ Share policies across projects |
| **Version control** | ✗ Hard to track changes | ✓ Easy to audit policy changes |
| **Best for** | Quick testing, simple policies | Production, complex policies |

## When to Use Each

**Use Heredoc (<<EOF) when:**
- Policy is very simple (few lines)
- Quick testing or prototyping
- Policy is unique to one resource

**Use file() when:**
- Policy is large or complex
- Multiple resources use the same policy
- Policy needs version control tracking
- Working in a team (easier to review)
- Managing production infrastructure

## IAM Policy Structure

An IAM policy is a JSON document with this structure:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow" | "Deny",
      "Action": "service:action",
      "Resource": "arn:aws:service:region:account-id:resource"
    }
  ]
}
```

### Policy Components

| Component | Description | Example |
|-----------|-------------|---------|
| **Version** | Policy language version (always "2012-10-17") | `"2012-10-17"` |
| **Statement** | Array of permission rules | `[ { ... } ]` |
| **Effect** | Allow or Deny the actions | `"Allow"` or `"Deny"` |
| **Action** | AWS service actions to allow/deny | `"s3:GetObject"`, `"iam:*"`, `"*"` |
| **Resource** | AWS resources the policy applies to | `"arn:aws:s3:::mybucket"`, `"*"` |

## Common IAM Policy Examples

### Full Administrator Access
```hcl
policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
```

### S3 Read-Only Access
```hcl
policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::mybucket",
        "arn:aws:s3:::mybucket/*"
      ]
    }
  ]
}
EOF
```

### DynamoDB Full Access
```hcl
policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "dynamodb:*",
      "Resource": "arn:aws:dynamodb:*:123456789012:table/MyTable"
    }
  ]
}
EOF
```

## Resource References

When attaching policies to users, you reference resource attributes:

```hcl
resource "aws_iam_user_policy_attachment" "example" {
  user       = aws_iam_user.admin-user.name      # References user's name
  policy_arn = aws_iam_policy.adminUser.arn      # References policy's ARN
}
```

**Commonly referenced attributes:**
- `aws_iam_user.name` — User's name
- `aws_iam_user.arn` — User's ARN
- `aws_iam_policy.arn` — Policy's ARN
- `aws_iam_policy.id` — Policy's ID
- `aws_iam_role.arn` — Role's ARN

## Complete IAM Setup Example

```hcl
# Create user
resource "aws_iam_user" "developer" {
  name = "john-dev"
  
  tags = {
    Environment = "Development"
    Team        = "Platform"
  }
}

# Create custom policy
resource "aws_iam_policy" "dev_policy" {
  name   = "DeveloperS3Access"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::dev-bucket",
        "arn:aws:s3:::dev-bucket/*"
      ]
    }
  ]
}
EOF
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "dev_access" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.dev_policy.arn
}

# Output user information
output "developer_user_name" {
  value = aws_iam_user.developer.name
}

output "developer_user_arn" {
  value = aws_iam_user.developer.arn
}
```

## Best Practices

1. **Use specific policies** — Don't always use AdministratorAccess
2. **Principle of least privilege** — Grant only necessary permissions
3. **Use managed policies** — AWS provides pre-defined policies
4. **Document policy purpose** — Add tags explaining what each policy does
5. **Separate by role** — Create different policies for different job functions
