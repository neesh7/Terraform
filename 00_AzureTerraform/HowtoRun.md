1. Setup backend from 04-* lab by running terraform apply
``` terraform apply -var-file=env/dev.tfvars ```
2. Then update the storage account ID into backend.tf and debug-dev.sh and run ``` ./.debug-dev.sh plan/apply/destroy```
3. 
setup virtual network from lab 07
then run vm creation from lab 08 or lab 09