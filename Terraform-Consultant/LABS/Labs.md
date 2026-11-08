# Terraform Azure Labs

Hands-on labs mapped to the notes in [../Notes](../Notes). Each lab builds on the previous one.
**You write the code.** This file only gives the goal, the tasks and how to verify them.

## Ground Rules (all labs)
- **Region:** `centralindia`. **Provider:** `hashicorp/azurerm ~> 4.0`. **Auth:** `az login` + `subscription_id` in `*.tfvars`
- **Naming:** `<type>-<project>-<env>-<nn>`, e.g. `rg-tfl-dev-01`, `sttfldev01` (storage accounts: lowercase letters and numbers, 3-24 chars)
- **Tags on everything:** `project`, `env`, `owner`, `managed_by = "terraform"`
- **Cost:** stick to RGs, VNets/subnets, NSGs, storage accounts, Key Vault and route tables (≈ free or a few rupees). **`terraform destroy` at the end of every lab** unless the next lab reuses the resources
- **Every lab follows this loop:** `fmt -recursive` → `validate` → `plan` → `apply` → verify → `destroy`
- Add a `.gitignore` per lab (`.terraform/`, `*.tfstate*`, secret `*.tfvars`, `crash.log`)

## Concept Coverage Matrix
| Concept (Notes file) | L02 | L03 | L04 | L05 | L06 | L07 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| Workflow, CLI, env vars, saved plan, `-target`, graph (00) | ✅ | | | | | ✅ |
| `terraform {}` settings, providers, provider `alias` (01) | ✅ | | | | ✅ | ✅ |
| Variables: types, validation, sensitive, precedence (01) | ✅ | | ✅ | | ✅ | ✅ |
| Outputs, data sources (01) | ✅ | ✅ | | | ✅ | ✅ |
| Meta-args: `depends_on`, `lifecycle` (01) | ✅ | | | | | ✅ |
| `terraform test` (01) | | | | | ✅ | |
| Remote backend, partial config, locking, migration (02) | | ✅ | | | | ✅ |
| `state` commands, `terraform_remote_state` (02) | | ✅ | | | | ✅ |
| Workspaces (02) | | ✅ | | | | |
| Drift detection, `-refresh-only` (02) | | ✅ | | | | ✅ |
| Functions, `terraform console` (03) | | | ✅ | | ✅ | ✅ |
| Dynamic values, conditionals, `for` expressions, `dynamic` blocks (03) | | | ✅ | | | ✅ |
| Locals (03) | | | ✅ | | ✅ | ✅ |
| `count` / `for_each` (03) | | | ✅ | ✅ | ✅ | ✅ |
| `moved` / `removed` / `import` blocks, `terraform import` (03) | | | | ✅ | ✅ | ✅ |
| Modules: local, isolation, outputs, `for_each` on modules (04) | | | | | ✅ | ✅ |
| Registry modules, versioning, `init -upgrade`, Git `?ref=` (04) | | | | | ✅ | ✅ |

---

## Lab-02: Workflow, Providers, Variables, Outputs & Lifecycle
**Folder:** `LABS/Lab-02` · **Notes:** 00, 01 · **Time:** ~60 min

### Goal
Build a small "app foundation" and practise every core block type and workflow command.

### Resources
- 1 Resource Group (primary region)
- 1 Storage Account + 1 private blob container
- 1 Resource Group in a **second region** (`southindia`) created through a provider **alias**

### Tasks
1. **Files:** split into `terraform.tf`, `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `dev.tfvars`
2. **Settings block:** `required_version` + `required_providers` for `azurerm` **and** `random`
3. **Providers:** a default `azurerm` provider plus a second one with `alias = "dr"`. Create the DR resource group using `provider = azurerm.dr`
4. **Variables.** Declare at least one of each:
   - `string` with `validation`: `env` must be `dev`, `test` or `prod`
   - `number` with validation: `retention_days` between 1 and 30
   - `bool`: `enable_versioning`
   - `list(string)`: `allowed_ips`
   - `map(string)`: `extra_tags`
   - `object({...})`: `storage = { tier = string, replication = string }`
   - one `sensitive = true` variable (e.g. `owner_email`), used in a tag
5. **Unique name:** use `random_string` to make the storage account name globally unique
6. **Data sources:** `data.azurerm_client_config.current`. Output the `tenant_id` and `object_id`
7. **Outputs:** RG name, storage account id, primary blob endpoint, and one `sensitive` output (the primary access key)
8. **Lifecycle:**
   - `prevent_destroy = true` on the storage account. Try `terraform destroy`, read the error, then remove the setting
   - `ignore_changes = [tags]` on the RG. Change a tag in the portal and confirm `plan` shows no change
   - `create_before_destroy` on the container. Change its name and watch the order in the plan
9. **Explicit dependency:** add `depends_on` from the DR RG to the primary storage account and check `terraform graph`

### Workflow drills
- Value **precedence:** set `env` via the default, then `terraform.tfvars`, then `dev.auto.tfvars`, then `TF_VAR_env`, then `-var-file`, then `-var`. Note which value wins each time
- Run `terraform plan -out=tfplan`, then `terraform show tfplan`, then `terraform apply tfplan` (no prompt)
- `terraform destroy -target=azurerm_storage_container.<name>`, then a normal apply to bring it back
- `terraform output -json`, and `terraform output -raw <name>`
- `terraform graph | dot -Tpng > graph.png` (optional, needs Graphviz)
- Turn on `TF_LOG=DEBUG` with `TF_LOG_PATH=./tf.log` for one plan, then turn it off

### Done when
- [ ] `terraform validate` passes, and `fmt -check` returns nothing
- [ ] An invalid `env` value fails with your custom error message
- [ ] The sensitive output shows `<sensitive>` in the CLI but is visible in `terraform.tfstate` (note this!)
- [ ] The DR RG exists in South India

---

## Lab-03: Remote State, State Commands, Workspaces & Drift
**Folder:** `LABS/Lab-03/bootstrap`, `LABS/Lab-03/network`, `LABS/Lab-03/app` · **Notes:** 02 · **Time:** ~75 min

### Goal
Move state to Azure, share it between configurations, and handle drift like in production.

### Tasks
**Part A: Bootstrap the backend** (`bootstrap/`, local state)
1. Create `rg-tfstate-01`, a storage account (versioning + soft delete ON) and a container `tfstate`
2. Output the names you need for the backend

**Part B: Local → remote migration** (`network/`)
1. Write a config with 1 RG + 1 VNet (`10.10.0.0/16`) + 2 subnets. Apply with **local** state first
2. Add an empty `backend "azurerm" {}` block and put the values in `backend.hcl` (**partial configuration**)
3. `terraform init -backend-config=backend.hcl -migrate-state`. Confirm the local state is gone and the blob exists
4. **Locking:** run `apply` in two terminals at the same time and read the lock error. Note the blob lease in the portal

**Part C: State commands** (`network/`)
1. `terraform state list`, then `terraform state show` on the VNet
2. `terraform state mv` to rename one subnet's address (then update the code to match so `plan` shows no changes)
3. `terraform state rm` on one subnet, then bring it back with `terraform import`
4. `terraform state pull > backup.tfstate` (keep it as a backup)

**Part D: Remote state data source** (`app/`, its own backend key)
1. Read `network`'s outputs with `data "terraform_remote_state"`
2. Create an NSG and associate it with a subnet whose ID comes from the remote state

**Part E: Workspaces** (`app/`)
1. `terraform workspace new dev` and `new prod`
2. Use `terraform.workspace` in names and pick a different NSG rule set per workspace (conditional)
3. Check where each workspace's state blob is stored (`env:` prefix in the key)

**Part F: Drift**
1. In the portal, add a tag to the VNet and change an NSG rule port
2. `terraform plan -refresh-only` to **detect** the drift
3. **Accept** the tag drift (`apply -refresh-only`, then update the code) and **revert** the port drift (normal `apply`)

### Done when
- [ ] No `terraform.tfstate` exists locally in `network/` or `app/`
- [ ] `app` gets subnet IDs only through `terraform_remote_state` (no hardcoding)
- [ ] `plan` returns **No changes** after every step
- [ ] You can explain: lost state vs lost access, and what versioning and soft delete gave you

---

## Lab-04: Making Code Reusable (Functions, Locals, Loops, Dynamic Blocks)
**Folder:** `LABS/Lab-04` · **Notes:** 03 (sections 1-4) · **Time:** ~75 min

### Goal
Describe a whole network with **one input map** and let Terraform work out the rest. No copy-pasted resource blocks.

### Input shape (design it in `variables.tf`)
```
vnet_cidr = "10.20.0.0/16"
subnets = {
  web = { newbits = 8, netnum = 1, nsg_rules = [ {name, priority, port, source} , ... ] }
  app = { newbits = 8, netnum = 2, nsg_rules = [ ... ] }
  db  = { newbits = 8, netnum = 3, nsg_rules = [ ... ] }
}
storage_accounts = ["logs", "data", "backup"]
```

### Tasks
1. **Locals:**
   - `name_prefix = "${var.project}-${var.env}"`
   - `common_tags = merge(default_tags, var.extra_tags)`
   - `is_prod = var.env == "prod"`
2. **Functions** (use each at least once):
   - `cidrsubnet()` to work out every subnet CIDR from `vnet_cidr`
   - `lower()`, `replace()` and `substr()` to build valid storage account names
   - `format()` / `join()` for names
   - `lookup()` with a default for an SKU map
   - `toset()`, `keys()`, `values()`, `length()`, `contains()`
   - `flatten()` to turn subnet → rules into one flat list of NSG rules
   - `coalesce()`, `try()` and `can()` for optional fields
3. **`for_each` on a map:** one subnet + one NSG per entry in `var.subnets`
4. **`for_each` on a set:** storage accounts from `toset(var.storage_accounts)`
5. **`count`:** create `count = local.is_prod ? 1 : 0` route tables (an optional resource toggle)
6. **`dynamic "security_rule"`** block inside the NSG, filled from each subnet's `nsg_rules`
7. **Conditional expression:** storage replication `GRS` in prod, `LRS` otherwise
8. **`for` expressions in outputs:**
   - `subnet_ids = { for k, s in azurerm_subnet.this : k => s.id }`
   - a list of upper-case storage names
   - a filtered map (`if`) of only subnets with more than one NSG rule
9. **Splat:** output `azurerm_storage_account.this[*]` vs `values(azurerm_storage_account.this)[*].name` (and why splat on a `for_each` map fails)

### Console drills (`terraform console`)
- `cidrsubnet("10.20.0.0/16", 8, 3)`, `cidrhost(...)`, `local.common_tags`, `var.subnets["web"].nsg_rules[0]`
- Try `max(var.numbers...)` with the expansion symbol

### Done when
- [ ] Adding a 4th subnet = **one map entry**, with no new resource blocks
- [ ] Switching `env = "prod"` creates the route table and changes replication. `plan` shows only those diffs
- [ ] Removing the `app` subnet from the map destroys **only** app resources (for_each keys are stable; compare with what `count` would do)

---

## Lab-05: Refactoring: `moved`, `removed`, `import`
**Folder:** `LABS/Lab-05` · **Notes:** 03 (sections 5-6) · **Time:** ~60 min

### Goal
Change code structure and adopt existing resources **without destroying anything**. The rule for this lab: **every plan must show 0 to destroy.**

### Setup
Start with deliberately "bad" code: 3 storage accounts created with `count`, a VNet named `azurerm_virtual_network.vnet1`, and a container you no longer want Terraform to manage. Apply it.

### Tasks
1. **Rename** `azurerm_virtual_network.vnet1` → `azurerm_virtual_network.main` with a `moved` block
2. **count → for_each:** convert the storage accounts to `for_each = toset(["logs","data","backup"])` with **one `moved` block per index** (`[0]` → `["logs"]`, ...)
3. **Stop managing** the container with a `removed` block + `lifecycle { destroy = false }`. Check it still exists in the portal
4. **Import, new way:** create an RG + a Key Vault **manually in the portal** (or with `az` CLI)
   - Write only `import` blocks in `imports.tf`
   - `terraform plan -generate-config-out=generated.tf`
   - Clean up `generated.tf` (remove read-only/default attributes, add variables and tags) until `plan` shows **only imports, no changes**
5. **Import, old way:** create a second NSG manually, write its resource block yourself, then `terraform import azurerm_network_security_group.legacy <id>`. Note that it went straight into state, with no plan
6. **`for_each` import:** import 2 manually created subnets into a `for_each` resource with an `import` block that uses `for_each` (TF 1.7+)
7. After everything is applied, **delete** the `moved`, `removed` and `import` blocks and confirm `plan` = No changes

### Done when
- [ ] Not a single plan in this lab showed a destroy or replace
- [ ] You can explain: `moved` vs `state mv`, `removed` vs `state rm`, `import` block vs CLI import (which is plannable, reviewable and works in CI)

---

## Lab-06: Modules: Write, Version, Consume
**Folder:** `LABS/Lab-06` (root) + a separate GitHub repo `terraform-azurerm-tfl-storage` · **Notes:** 04 · **Time:** ~90 min

### Goal
Turn Lab-04's code into reusable modules, consume a Registry module, and practise versioning.

### Structure
```
Lab-06/
├── main.tf / variables.tf / outputs.tf / terraform.tf / providers.tf
├── envs/dev.tfvars, envs/prod.tfvars
├── modules/
│   ├── network/   (vnet + subnets + nsgs + dynamic rules)
│   └── naming/    (locals only: returns names via outputs)
└── tests/network.tftest.hcl
```

### Tasks
1. **Local `network` module**
   - Standard files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` (only `required_providers` with `>=`, **no `provider` block**), `README.md`
   - Typed, described and validated inputs: required (`resource_group_name`, `vnet_cidr`, `subnets`) and optional (`location`, `tags`)
   - Outputs: `vnet_id`, `subnet_ids` (map)
2. **Variable isolation drills**
   - Inside the module, reference a root variable (`var.project`) that the module didn't declare and read the error
   - Pass an argument the module doesn't declare and read the `Unsupported argument` error
   - Leave out a required input and read the `Missing required argument` error
3. **`naming` module:** a module with **no resources**, only locals and outputs, that returns standard names. The network module's caller uses its outputs
4. **`for_each` on a module:** deploy the network module for 2 spokes (`spoke1`, `spoke2`) from a map. Output `{ for k, m in module.network : k => m.vnet_id }`
5. **Move into a module:** take Lab-04-style root resources (apply them first), then move them into `module.network` with `moved` blocks. **0 to destroy**
6. **Git-sourced module, with versioning**
   - Push a small `storage` module to your GitHub repo `terraform-azurerm-tfl-storage` and tag it `v1.0.0`
   - Consume it with `git::https://github.com/<you>/terraform-azurerm-tfl-storage.git?ref=v1.0.0`
   - Add an optional `enable_versioning` input and tag `v1.1.0`. Bump `?ref=`, then `terraform init`
   - Make a **breaking** change (rename an input) and tag `v2.0.0`. Note why that's a MAJOR bump
7. **Public Registry module**
   - Use `Azure/naming/azurerm` (or an Azure Verified Module, `Azure/avm-res-...`) with `version = "~> x.y"`
   - Pin it to an **older** version first, then loosen the constraint and run `terraform init` (no change), then `terraform init -upgrade` (it upgrades). Look in `.terraform/modules/modules.json`
   - Confirm that `.terraform.lock.hcl` did **not** record the module version
8. **`terraform test`:** write `tests/network.tftest.hcl` with a `run` block (`command = plan`) that asserts there are 3 subnets and the subnet names start with `snet-`. Optional: `mock_provider "azurerm"` so the test runs without Azure
9. **Two environments:** `terraform plan -var-file=envs/prod.tfvars`. The same modules, with different inputs

### Done when
- [ ] The root `main.tf` contains **only** `module` blocks (plus the RG), with no raw networking resources
- [ ] State addresses look like `module.network["spoke1"].azurerm_subnet.this["web"]`
- [ ] `terraform test` passes
- [ ] You can explain where each version is controlled: local (none), Git (`?ref=`), Registry (`version`), providers (lock file)

---

## Lab-07: Capstone: Hub-Spoke Landing Zone (Everything Together)
**Folder:** `LABS/Lab-07` · **Notes:** all · **Time:** 2-3 hrs

### Scenario
> Your team wants a reusable hub-spoke network for **dev** and **prod**. Part of it already exists (created by hand). Build it the production way.

### Requirements
1. **Layout:** directory per environment (`envs/dev`, `envs/prod`), each a thin root module calling the shared `modules/`. Separate state keys per env in the **Lab-03 backend** (partial config)
2. **Modules**
   - `hub` (VNet, `AzureFirewallSubnet`-style reserved subnet, shared Key Vault)
   - `spoke` (reused with `for_each` for `app` and `data` spokes)
   - `peering` (hub↔spoke, both directions)
   - one **Registry** module for naming
3. **Remote state split:** a `foundation` stack (hub) and a `workloads` stack (spokes + peering) that reads the hub's outputs through `terraform_remote_state`
4. **Brownfield:** create the `data` spoke VNet manually before you start, then adopt it with an `import` block **inside the module address** (`to = module.spoke["data"].azurerm_virtual_network.this`)
5. **Reusability:** all CIDRs worked out with `cidrsubnet()` from one `/16` per env. NSG rules through `dynamic` blocks. Tags through `merge()`. Prod-only resources toggled with conditional `count`
6. **Safety**
   - `prevent_destroy` on the hub VNet and the Key Vault
   - `sensitive` outputs for anything secret
   - variable `validation` on env, CIDR (`can(cidrhost(...))`) and region
7. **Refactor mid-way:** rename `module.spoke` → `module.spokes` with a `moved` block (0 destroy)
8. **Drift exercise:** delete one peering in the portal, then detect it with `plan -refresh-only` and fix it with `apply`
9. **CI-style run:** `terraform fmt -check -recursive && terraform validate && terraform plan -out=tfplan -input=false`, then `terraform apply tfplan`, with credentials from `ARM_*` env vars (no `az login`)

### Done when
- [ ] `dev` and `prod` deploy from the **same modules** with only `.tfvars` and backend key differences
- [ ] `peering` works both ways (check effective routes, or `az network vnet peering list`)
- [ ] Import, rename and drift steps all finish with **No changes**
- [ ] Clean `terraform destroy` for prod (after removing `prevent_destroy`), and the backend RG kept

### Stretch
- Add `check` blocks (TF 1.5+) that assert the Key Vault has soft delete and purge protection
- Use `templatefile()` to render a README/inventory file from outputs with `local_file`
- Run `terraform test` for the `spoke` module in CI with `mock_provider`

---

## Progress Tracker
| Lab | Topic | Status |
|---|---|---|
| Lab-01 | First resource group | ✅ |
| Lab-02 | Workflow, providers, variables, outputs, lifecycle | ⏳ |
| Lab-03 | Remote state, state cmds, workspaces, drift | ⏳ |
| Lab-04 | Functions, locals, loops, dynamic blocks | ⏳ |
| Lab-05 | moved / removed / import | ⏳ |
| Lab-06 | Modules, versioning, Registry, tests | ⏳ |
| Lab-07 | Capstone hub-spoke | ⏳ |
