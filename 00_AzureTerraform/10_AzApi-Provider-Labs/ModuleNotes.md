Till now we have used 2 terraform providers
- azurerm
- azuread
but now we are going to explore another provider called 'azapi'.


Terraform Providers are independent pieces of software that extend the terraform core cli to allow us to talk different platform.

In Azurerm provider what's happening it is eseentially using azure sdk in golang sdk for azure

If any new feature released in azure then there is some custom coding involved in azurerm provider where author basically writes how to achieve that piece in terraform and this causes a delay and delay can be long or short.

AzureAPI provider on the other hand is maintained by microsoft itself so it have the day 0 support to any of this features.

How azure api provider work and different from azurerm provider ?

- Day 0 Support to any azure feature
- it Allows us to use the official schema of that azure resource, rather than a proprietary abstraction that is built in to terraform provider.
Resources

https://learn.microsoft.com/en-us/azure/templates/
https://registry.terraform.io/providers/Azure/azapi/latest