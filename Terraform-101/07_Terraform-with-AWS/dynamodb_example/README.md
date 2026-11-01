# Terraform AWS DynamoDB Example

This example demonstrates how to create and configure a DynamoDB table with various features using Terraform.

## Directory Structure

```
dynamodb_example/
├── main.tf           # Main DynamoDB table configuration
├── variables.tf      # Input variables
├── outputs.tf        # Output values
└── README.md         # This file
```

## Features

✅ **DynamoDB Table Creation** — Create tables with partition and sort keys  
✅ **Flexible Billing** — Pay-per-request or provisioned capacity  
✅ **Global Secondary Index (GSI)** — Additional query patterns  
✅ **Point-In-Time Recovery** — Automatic backups  
✅ **Encryption** — Server-side encryption at rest  
✅ **TTL Support** — Auto-delete expired items  

## Resources Created

1. **aws_dynamodb_table** — Main DynamoDB table
2. **aws_dynamodb_table_gsi** — Global Secondary Index (optional)

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | us-east-1 | AWS region |
| `table_name` | string | terraform-table | Table name |
| `environment` | string | dev | Environment |
| `billing_mode` | string | PAY_PER_REQUEST | Billing mode |
| `hash_key` | string | id | Partition key |
| `range_key` | string | "" | Sort key (optional) |
| `read_capacity_units` | number | 5 | Read capacity (PROVISIONED) |
| `write_capacity_units` | number | 5 | Write capacity (PROVISIONED) |
| `enable_pitr` | bool | true | Point-In-Time Recovery |
| `ttl_attribute_name` | string | "" | TTL attribute (optional) |
| `create_gsi` | bool | false | Create Global Secondary Index |

## Usage

### 1. Initialize Terraform
```bash
cd dynamodb_example
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Apply Configuration (On-Demand Billing)
```bash
terraform apply
```

### 4. Provisioned Capacity Example
```bash
terraform apply \
  -var="billing_mode=PROVISIONED" \
  -var="read_capacity_units=10" \
  -var="write_capacity_units=10"
```

### 5. With Sort Key
```bash
terraform apply \
  -var="hash_key=user_id" \
  -var="range_key=timestamp"
```

### 6. With Global Secondary Index
```bash
terraform apply \
  -var="create_gsi=true" \
  -var="gsi_partition_key=email"
```

### 7. With TTL (Auto-delete items)
```bash
terraform apply \
  -var="ttl_attribute_name=expires_at"
```

### 8. View Outputs
```bash
terraform output
```

## Example Output

```
billing_mode = "PAY_PER_REQUEST"
encryption_enabled = true
gsi_created = "No"
hash_key = "id"
pitr_enabled = true
range_key = "None"
table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/terraform-table"
table_id = "terraform-table"
table_name = "terraform-table"
table_status = "ACTIVE"
ttl_enabled = "Disabled"
```

## Billing Modes

### PAY_PER_REQUEST (Recommended for unpredictable workloads)
```bash
terraform apply -var="billing_mode=PAY_PER_REQUEST"
```
- Pay per request
- Auto-scales
- Best for variable/unknown workloads

### PROVISIONED (For predictable workloads)
```bash
terraform apply \
  -var="billing_mode=PROVISIONED" \
  -var="read_capacity_units=10" \
  -var="write_capacity_units=10"
```
- Fixed hourly cost
- Pre-defined capacity
- Cost-effective for steady workloads

## Key Attributes

### Partition Key (Hash Key)
- Required
- Determines distribution across partitions
- Example: `id`, `user_id`, `email`

### Sort Key (Range Key)
- Optional
- Allows complex queries
- Example: `timestamp`, `name`, `status`

### Global Secondary Index (GSI)
- Optional secondary way to query
- Different partition/sort key
- Useful for multi-dimensional access patterns

## Advanced Features

### Point-In-Time Recovery (PITR)
Restore table to any point in the last 35 days:
```hcl
enable_pitr = true
```

### TTL (Time To Live)
Automatically delete items after expiration:
```hcl
ttl_attribute_name = "expires_at"
```

Items with `expires_at` timestamp in the past are automatically deleted.

### Encryption
Server-side encryption enabled by default:
```hcl
server_side_encryption_specification {
  enabled = true
}
```

## Data Model Example

If creating a user table with email GSI:

```hcl
hash_key         = "user_id"
range_key        = "created_at"
create_gsi       = true
gsi_partition_key = "email"
```

This allows:
- Query users by `user_id` (primary)
- Query users by `email` (GSI)

## Common Patterns

### Simple Key-Value Store
```bash
hash_key = "pk"
range_key = ""
billing_mode = "PAY_PER_REQUEST"
```

### User Table with Timestamps
```bash
hash_key = "user_id"
range_key = "timestamp"
enable_pitr = true
```

### Multi-Query Table with GSI
```bash
hash_key = "pk"
range_key = "sk"
create_gsi = true
gsi_partition_key = "email"
```

## Cleanup

Delete all resources:
```bash
terraform destroy
```

Type `yes` to confirm.

## Cost Considerations

- **On-Demand:** $1.25 per million write units, $0.25 per million read units
- **Provisioned:** Charged hourly for provisioned capacity
- **Storage:** $0.25 per GB-month
- **Backups:** $0.20 per GB-month for PITR and on-demand backups

## Security Best Practices

1. ✓ Enable encryption (default)
2. ✓ Enable PITR for disaster recovery
3. ✓ Use fine-grained IAM policies
4. ✓ Enable CloudTrail logging
5. ✓ Use TTL to manage data lifecycle
6. ✓ Monitor with CloudWatch

## Notes

- Tables take a few seconds to become ACTIVE
- Throughput can be increased anytime, decreased after 1 hour
- Global Secondary Indexes have separate capacity
- On-demand billing scales automatically
