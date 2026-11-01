# Terraform Commands

## Format
```bash
terraform fmt         # Format config files to the canonical style
```

## Init
```bash
terraform init        # Download providers & modules, configure backend, create/update .terraform.lock.hcl
```

## Validate
```bash
terraform validate    # Check config for syntax and internal consistency (needs init first)
```

## Plan
```bash
terraform plan                        # Preview changes (dry run)
terraform plan -out=myplan.tfplan     # Save the plan to a file for review/approval
```

## Apply
```bash
terraform apply                       # Standard apply: runs a plan, then prompts for confirmation
terraform apply myplan.tfplan         # Apply a saved plan exactly as reviewed (no prompt)
terraform apply -auto-approve         # Skip the confirmation prompt (use carefully)
terraform apply -input=false          # Disable interactive input prompts (automation/CI/CD)
terraform apply -parallelism=5        # Change the number of parallel operations (default: 10)
```

## Destroy
```bash
terraform destroy                                   # Destroy all resources managed by this configuration
terraform destroy -target=<resource_type>.<name>    # Destroy a single specific resource
```
