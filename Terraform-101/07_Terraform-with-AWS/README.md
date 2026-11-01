# Terraform AWS IAM Setup with External Policy Files

This example demonstrates how to create IAM users and attach policies referenced from external JSON files.

## Directory Structure

```
07_Terraform-with-AWS/
├── main.tf                          # Main configuration with users and policy attachments
├── variables.tf                     # Input variables
├── outputs.tf                       # Output values
├── README.md                        # This file
└── policies/                        # Directory containing IAM policy JSON files
    ├── admin_policy.json           # Full administrator access
    ├── s3_read_only_policy.json    # S3 read-only access
    └── dynamodb_policy.json        # DynamoDB full access
```

## Files Overview

### main.tf
Creates three IAM users with different permissions:
- **admin-user** — Full AWS access (AdministratorAccess)
- **dev-user** — S3 read-only access
- **dynamodb-dev-user** — DynamoDB full access

Each user gets a policy attached using `aws_iam_user_policy_attachment`.

### variables.tf
Defines input variables:
- `aws_region` — AWS region (default: us-east-1)

### outputs.tf
Displays created resources:
- User names and ARNs
- Policy ARNs

### policies/ Directory
Contains JSON policy files:
- **admin_policy.json** — Allows all actions on all resources
- **s3_read_only_policy.json** — Allows S3 GetObject and ListBucket
- **dynamodb_policy.json** — Allows all DynamoDB actions

## Key Features

### Using file() Function
Instead of inline heredoc (<<EOF), policies are stored in separate files:

```hcl
policy = file("${path.module}/policies/admin_policy.json")
```

**Benefits:**
- Cleaner code
- Easier to maintain and review
- Better version control tracking
- Reusable across projects

### Resource References
Resources reference each other using their attributes:

```hcl
resource "aws_iam_user_policy_attachment" "admin_access" {
  user       = aws_iam_user.admin.name           # Reference user name
  policy_arn = aws_iam_policy.admin_policy.arn   # Reference policy ARN
}
```

## How to Use

### 1. Set AWS Credentials
```bash
# Set environment variables or use ~/.aws/credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

### 2. Initialize Terraform
```bash
cd 07_Terraform-with-AWS
terraform init
```

### 3. Review the Plan
```bash
terraform plan
```

This will show what resources will be created:
- 3 IAM users
- 3 IAM policies
- 3 policy attachments

### 4. Apply the Configuration
```bash
terraform apply
```

Type `yes` to confirm and create the resources.

### 5. View Outputs
```bash
terraform output
```

Shows the created user names, ARNs, and policy ARNs.

## Example Output

```
admin_policy_arn = "arn:aws:iam::123456789012:policy/AdminPolicy"
admin_user_arn = "arn:aws:iam::123456789012:user/admin-user"
admin_user_name = "admin-user"
dynamodb_developer_user_arn = "arn:aws:iam::123456789012:user/dynamodb-dev-user"
dynamodb_developer_user_name = "dynamodb-dev-user"
dynamodb_policy_arn = "arn:aws:iam::123456789012:policy/DynamoDBDeveloperPolicy"
developer_user_arn = "arn:aws:iam::123456789012:user/dev-user"
developer_user_name = "dev-user"
s3_policy_arn = "arn:aws:iam::123456789012:policy/S3ReadOnlyPolicy"
```

## Cleanup

To delete all created resources:

```bash
terraform destroy
```

Type `yes` to confirm deletion.

## Notes

- The `${path.module}` variable ensures policies are referenced relative to the Terraform configuration directory
- All three users will have programmatic access disabled by default (can be enabled separately)
- These are custom IAM policies; AWS also provides managed policies
- For production, use more restrictive policies (principle of least privilege)

## Learning Points

This example demonstrates:
1. ✓ Creating IAM users with Terraform
2. ✓ Referencing external policy files with `file()`
3. ✓ Attaching policies to users
4. ✓ Using `${path.module}` for relative paths
5. ✓ Resource references and interpolation
6. ✓ Output values for resource information
