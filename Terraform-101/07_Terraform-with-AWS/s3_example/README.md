# Terraform AWS S3 Bucket Example

This example demonstrates how to create and configure an S3 bucket with security best practices using Terraform.

## Directory Structure

```
s3_example/
├── main.tf           # Main S3 bucket configuration
├── variables.tf      # Input variables
├── outputs.tf        # Output values
└── README.md         # This file
```

## Features

✅ **S3 Bucket Creation** — Creates a new S3 bucket with tags  
✅ **Versioning** — Optional version control for objects  
✅ **Security** — Blocks all public access by default  
✅ **Encryption** — Server-side encryption (AES256)  
✅ **Sample File Upload** — Optional file upload to the bucket  

## Resources Created

1. **aws_s3_bucket** — Main S3 bucket
2. **aws_s3_bucket_versioning** — Enable/disable versioning
3. **aws_s3_bucket_public_access_block** — Block public access (security)
4. **aws_s3_bucket_server_side_encryption_configuration** — Enable encryption
5. **aws_s3_object** — Optional sample file

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | us-east-1 | AWS region |
| `bucket_name` | string | my-terraform-bucket-12345 | S3 bucket name (must be globally unique) |
| `environment` | string | dev | Environment name |
| `enable_versioning` | bool | true | Enable object versioning |
| `upload_sample_file` | bool | false | Upload sample file |

## Usage

### 1. Initialize Terraform
```bash
cd s3_example
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Apply Configuration
```bash
terraform apply
```

### 4. Using Custom Values
```bash
terraform apply -var="bucket_name=my-unique-bucket-name" -var="environment=prod"
```

### 5. Upload Sample File
```bash
terraform apply -var="upload_sample_file=true"
```

### 6. View Outputs
```bash
terraform output
```

## Example Output

```
bucket_access = "Blocked (secure)"
bucket_arn = "arn:aws:s3:::my-terraform-bucket-12345"
bucket_domain_name = "my-terraform-bucket-12345.s3.us-east-1.amazonaws.com"
bucket_id = "my-terraform-bucket-12345"
bucket_region = "us-east-1"
encryption_type = "AES256"
versioning_enabled = "Enabled"
```

## Key Configurations

### Versioning
Enable versioning to maintain multiple versions of objects:
```hcl
enable_versioning = true
```

### Public Access Block
Prevents accidental public exposure:
```hcl
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true
```

### Server-Side Encryption
Encrypts objects at rest:
```hcl
sse_algorithm = "AES256"
```

## Accessing S3 Objects

After creation, access files with:
```
https://bucket-name.s3.us-east-1.amazonaws.com/object-key
```

Example:
```
https://my-terraform-bucket-12345.s3.us-east-1.amazonaws.com/sample.txt
```

## Security Best Practices

1. ✓ Block all public access by default
2. ✓ Enable versioning for recovery
3. ✓ Enable encryption for data protection
4. ✓ Use bucket policies to control access
5. ✓ Enable logging for audit trails
6. ✓ Use unique, descriptive bucket names
7. ✓ Tag resources for organization

## Cleanup

Delete all resources:
```bash
terraform destroy
```

Type `yes` to confirm.

## Notes

- **Bucket names must be globally unique** across all AWS accounts
- S3 bucket names follow DNS naming rules (lowercase, hyphens, etc.)
- Versioning can increase storage costs
- Encryption has minimal performance impact
- Objects are private by default (secure)
