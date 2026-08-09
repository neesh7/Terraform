## Terraform

Terraform is an IAC Tool used to provision cloud infra.

Terraform benefits:

1. Idempotence
    By this we mean when we run terraform apply the goal is to get a desired state of infra as described in config file. Running multiple time tf apply
    won't result any difference in desired state.

2. Immutibility
   Terraform is immutable because when there is a change in config file or a drift or diff is observed it recreates the whole infra to maintain consistency and minimize configuration bugs.

3. Encapsulation
        Encapsulation is achieved in Terraform using Modules, which hide complex infrastructure code inside a sealed container. Users can only interact with that infrastructure through safely exposed Input Variables and Output Values, like plugging into a clean interface
4. Cohesion
    The principle of cohesion in Terraform means grouping closely related infrastructure resources into a single module that does one specific job

5. Declarative
    Terraform is declarative because we define our desired state in configuration files and by tf apply we just achieve that.

6. DRY Principal ( Do Not Repeat yourself)
   write simple and clean tf code don't go on over engineering it

7. Cloud Agnostics


Local vs Input variables

The core difference is that input variables act as arguments passed into a module from the outside, whereas local values act as private, internal constants used inside the module
The Key BreakdownInput Variables (variable):

Like function parameters. They allow users to pass different values into your Terraform code when they run it.

Local Values (locals): Like private variables inside a function. They calculate or store values internally, and users outside the module cannot see or change them.

# Input Variables: declare vs assign

- `variables.tf` = **declaration** (like a function signature): name, `type`, `description`, optional `default`. Always required.
- `terraform.tfvars` = **value assignment** (like function arguments). One of several ways to pass values.

Value precedence (later wins):

1. `default` in variable block
2. Env var `TF_VAR_<name>`
3. `terraform.tfvars` (auto-loaded)
4. `*.auto.tfvars` (auto-loaded, alphabetical)
5. `-var-file` (e.g. `terraform plan -var-file prod.tfvars` — how you pick an env; named files like `prod.tfvars`/`dev.tfvars` are never auto-loaded)
6. `-var "name=value"` (CLI)

No value found + no default → Terraform prompts interactively.

Best practice: declare everything in `variables.tf` with type + description; use per-env files (`dev.tfvars`, `prod.tfvars`) with `-var-file`; use `TF_VAR_*` for secrets in CI; don't commit tfvars containing secrets.

# Commands
terraform init
terraform validate
terraform plan
terraform apply
terraform destroy

terraform output "application_name"
terraform plan -var "application_name=webapp" -var "environment_name=tip"

terraform workspace list
# Questions
What is local variable vs input variables?

check registry.terraform.io


# How to set env variable in powershell
$env:API_KEY = "foo"
write-host $API_KEY

#### Right way to do it
$env:TF_VAR_api_key = "foo"

#### Bash equivalent
export TF_VAR_api_key="foo"
echo $TF_VAR_api_key

Note: once `TF_VAR_api_key` is set in the environment, `terraform plan`/`apply` picks the value from there automatically —
no interactive prompt for `var.api_key` even if it has no default. Great for secrets: value never lands in a file.


## Terraform workspace
Terraform workspace allows you to switch between different instaces of your state file in root module
```
terraform workspace list 
terraform workspace new <env-name>
terraform workspace select <env-name>
terraform workspace delete <env-name>
terraform workspace show <env-name>

```

## Terraform modules

In Terraform modules are a way to group resources, package them and deliver them as one component.

In the most simplest word terraform modules are similar to python modules / codes that we write and import or reuse it other code.
Basically, we write a terraform module code ( basically the function) and whenever we need to create that resource we just import or refer that module pass the specification and spin up the infra.

Every terraform env is itself a module called root module.

All modules in terraform are scoped by single folder including our terraform solution itself which is special module called root module.

## Terraform console
terraform console
random_string.suffix