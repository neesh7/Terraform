# Configuring the Terraform Backend

1. We've to add terraform providers + subscription id, which is mandatory as per new versions.
2. First create resource group using terraform with proper naming convention.
3. Using terraform workspace to keep our dev and prod isolated (but it's not a true isolation, as the config file is still common).
4. Create blob container so that we can store our tfstate files.
5. Follow these resource abbreviations to create resources in terraform: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations