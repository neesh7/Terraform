# Setting Up Terraform with Azure Blob Storage Remote State

This example demonstrates how to configure Terraform with Azure Blob Storage as a remote state backend.

## Prerequisites

1. **Azure CLI** installed and authenticated
2. **Terraform** installed (v1.0+)
3. Azure subscription with appropriate permissions

## Setup Steps

### Step 1: Create Azure Storage Account for State (One-time setup)

```bash
# Set variables
RESOURCE_GROUP="terraform-state-rg"
STORAGE_ACCOUNT="tfstateaccount"
CONTAINER="tfstate"
LOCATION="eastus"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_GRS \
  --encryption-services blob

# Create blob container
az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT
```

### Step 2: Configure Terraform Variables

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit and add your subscription ID
# vim terraform.tfvars
```

**terraform.tfvars should contain:**
```hcl
subscription_id = "your-subscription-id-here"
environment     = "dev"
location        = "East US"
```

### Step 3: Initialize Terraform

```bash
# Initialize Terraform with remote backend
terraform init

# You'll be prompted to authenticate with Azure if not already done
# Choose option 1 (Device Login) or provide storage account key/SAS token
```

### Step 4: Plan and Apply

```bash
# Review changes
terraform plan

# Apply configuration
terraform apply
```

### Step 5: Verify Remote State

```bash
# Check state is stored remotely
terraform state list

# View specific resource
terraform state show azurerm_resource_group.app
```

## Verifying State in Azure Portal

1. Go to **Storage Accounts** → your storage account
2. Navigate to **Containers** → `tfstate`
3. You should see `prod/terraform.tfstate` file

## Key Advantages of This Setup

✅ **State Locking** — Azure Blob Storage leases prevent concurrent operations  
✅ **Encryption** — State encrypted at rest and in transit  
✅ **Versioning** — Blob versions track state history  
✅ **Team Access** — Multiple team members can safely work on same infrastructure  
✅ **CI/CD Integration** — Easy to integrate with pipelines (GitHub Actions, Azure DevOps)  

## Troubleshooting

**Issue: "Authentication failed"**
- Run `az login` to authenticate with Azure
- Ensure your user has "Storage Blob Data Owner" role on storage account

**Issue: "Container not found"**
- Verify storage account and container exist in Azure Portal
- Check the names match in backend configuration

**Issue: State lock timeout**
- Another `terraform apply` is running
- Check who's running it and wait for completion
- Or use `terraform force-unlock` (use with caution)

## Security Best Practices

1. **Enable Storage Account Firewall** — Restrict access by IP
2. **Use Managed Identity** — For CI/CD, use service principals with minimal permissions
3. **Enable Soft Delete** — Protect against accidental deletion
4. **Audit Logging** — Enable Azure Storage logging for compliance
5. **Don't commit tfvars** — Add `terraform.tfvars` to `.gitignore`

## Important Notes

- **Never** commit `terraform.tfvars` (contains sensitive data)
- **Never** manually edit state files
- Always use `terraform state` commands for modifications
- Backup state regularly (enable blob versioning)
- Restrict IAM access to storage account

## Next Steps

- Add more resources to `main.tf`
- Set up multiple environments (dev, staging, prod) with separate keys
- Implement Terraform Workspace for environment separation
- Add state encryption and access controls
